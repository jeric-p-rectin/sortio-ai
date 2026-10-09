import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../db/sortio_db.dart';
import '../fs/file_ops.dart';
import '../llm/llm_client.dart';
import '../models/action_record.dart';
import '../models/ids.dart';
import '../models/results.dart';
import '../models/suggestion.dart';
import '../naming/date_extractor.dart';
import '../naming/rename_service.dart';
import '../privacy/network_status.dart';
import '../rules/house_rules.dart';
import '../rules/rules_engine.dart';
import '../safety/validator.dart';
import '../search/search_query.dart';
import 'sortio_core.dart';

/// Runs OCR on a file and returns its text ('' if none). Provided by the
/// Flutter layer (ML Kit); the core caches the result.
typedef OcrFunction = Future<String> Function(String path);

/// The real, on-device implementation of [SortioCore].
class LocalSortioCore implements SortioCore {
  static const quarantineFolderName = RulesEngine.quarantineCategory;

  final SortioDb _db;
  final RulesEngine _rules;
  Validator _validator;
  bool _indexedThisSession = false;

  /// The user's plain-words rules (Settings → House rules). They win over
  /// the built-in category rules.
  HouseRules houseRules = HouseRules.empty;

  /// Camera / picture folders. Ordinary photos there are never touched:
  /// only recent images that turn out to be documents (by OCR) are suggested.
  Set<String> photoRoots = const {};

  /// How far back to look in [photoRoots].
  Duration photoWindow = const Duration(days: 30);

  static const photoCategory = 'Scans';

  /// [dataDir] is app-private storage for the database, e.g. Flutter's
  /// `getApplicationSupportDirectory()`.
  LocalSortioCore({
    required String dataDir,
    List<String> allowedFolders = const [],
    RulesEngine? rules,
  }) : this.withDb(SortioDb.open(dataDir),
            allowedFolders: allowedFolders, rules: rules);

  LocalSortioCore.withDb(
    this._db, {
    List<String> allowedFolders = const [],
    RulesEngine? rules,
  })  : _rules = rules ?? RulesEngine(),
        _validator = Validator(allowedFolders);

  SortioDb get db => _db;

  List<String> get allowedFolders => _validator.roots;

  void setAllowedFolders(List<String> folders) {
    _validator = Validator(folders);
    _indexedThisSession = false;
  }

  void close() => _db.close();

  // --- Scan / apply / undo ---------------------------------------------------

  @override
  Future<List<Suggestion>> scan(List<String> allowedFolders) async {
    setAllowedFolders(allowedFolders);
    await refreshIndex();
    final suggestions = <Suggestion>[];
    final claimed = <String>{};
    final duplicates = await findDuplicates();

    for (final folder in _validator.roots) {
      final dir = Directory(folder);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (RulesEngine.isIgnored(name)) continue;
        final indexed = _db.file(entity.path);

        final original = duplicates[entity.path];
        if (original != null) {
          suggestions.add(_duplicateSuggestion(entity.path, folder, original, claimed));
          continue;
        }

        if (photoRoots.contains(folder)) {
          final photo = _photoSuggestion(entity, folder, indexed, claimed);
          if (photo != null) suggestions.add(photo);
          continue;
        }

        final match = _rules.classify(name);
        final houseRule = houseRules.match(name, indexed?.ocrText);
        if (match == null && houseRule == null) continue;

        final needsRename = match?.needsRename ?? false;
        // Reuse a cached AI name so rescans are instant.
        final aiName = needsRename ? indexed?.aiName : null;
        final learned = houseRule == null
            ? learnedFolder(aiName ?? name)
            : null;
        final category = houseRule?.folder ?? learned ?? match!.category;
        final target =
            uniqueTarget(p.join(folder, category, aiName ?? name), claimed);
        claimed.add(p.canonicalize(target));
        suggestions.add(Suggestion(
          id: newId(),
          type: ActionType.move,
          sourcePath: entity.path,
          targetPath: target,
          reason: houseRule != null
              ? 'Your rule: "${houseRule.source}"'
              : learned != null
                  ? '$learnedPrefix → $category'
                  : aiName != null
                      ? 'Named from its content → $category'
                      : match!.reason,
          confidence: houseRule != null
              ? 1.0
              : learned != null
                  ? 0.92
                  : match!.confidence,
          category: category,
          needsRename: needsRename && aiName == null,
          aiNamed: aiName != null,
        ));
      }
    }

    suggestions.sort((a, b) {
      final c = (a.category ?? '').compareTo(b.category ?? '');
      return c != 0 ? c : a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    });
    return suggestions;
  }

  /// AI rename for suggestions flagged [Suggestion.needsRename].
  ///
  /// Emits an updated copy of each suggestion (same `id`, new target name,
  /// `aiNamed: true`) as soon as it is ready, so the UI can replace items one
  /// by one while the model works. OCR text and AI names are cached, so each
  /// file goes through OCR and the model at most once.
  ///
  /// [ocr] is called for files that have not been OCR'd yet; without it those
  /// files are skipped. Files the model fails on are skipped, not fatal.
  Stream<Suggestion> aiRename(
    List<Suggestion> suggestions,
    RenameService service, {
    OcrFunction? ocr,
  }) async* {
    final claimed = {for (final s in suggestions) p.canonicalize(s.targetPath)};

    for (final s in suggestions) {
      if (!s.needsRename || s.type == ActionType.createFolder) continue;
      final indexed = _db.file(s.sourcePath);
      if (indexed == null) continue;

      var text = indexed.ocrText;
      if (text == null && ocr != null) {
        try {
          text = await ocr(s.sourcePath);
        } on Object {
          continue;
        }
        _db.saveOcrText(s.sourcePath, text);
      }
      if (text == null || text.trim().isEmpty) continue;

      var newName = indexed.aiName;
      var reason = 'Named from its content';
      var confidence = 0.8;
      if (newName == null) {
        final RenameProposal? proposal;
        try {
          proposal = await service.propose(
            fileName: s.fileName,
            ocrText: text,
            modified: indexed.modified,
          );
        } on LlmException {
          continue;
        }
        if (proposal == null) continue;
        newName = proposal.newName;
        reason = proposal.reason;
        confidence = proposal.confidence;
        _db.saveAiName(s.sourcePath, newName);
      }

      claimed.remove(p.canonicalize(s.targetPath));
      // "Meralco files usually go to Bills": an issuer habit picks the folder.
      final root = _validator.rootOf(s.sourcePath);
      final issuerHabit = root == null || s.reason.startsWith('Your rule')
          ? null
          : _habitFor(issuerKey(newName));
      final folder = issuerHabit != null
          ? p.join(root!, issuerHabit)
          : p.dirname(s.targetPath);
      final category = issuerHabit ?? s.category;
      final target = uniqueTarget(p.join(folder, newName), claimed);
      claimed.add(p.canonicalize(target));

      yield Suggestion(
        id: s.id,
        type: s.type,
        sourcePath: s.sourcePath,
        targetPath: target,
        reason: issuerHabit != null
            ? '$reason · $learnedPrefix → $issuerHabit'
            : category == null
                ? reason
                : '$reason → $category',
        confidence: confidence,
        category: category,
        aiNamed: true,
      );
    }
  }

  // --- Duplicates ------------------------------------------------------------

  /// Exact copies across the allowed folders: copy path → the file it
  /// duplicates. Files are grouped by size first, so only same-size files are
  /// hashed, and hashes are cached until the file changes. The copy kept is
  /// one that is already filed in a sub-folder, else the oldest.
  Future<Map<String, String>> findDuplicates() async {
    final bySize = <int, List<IndexedFile>>{};
    for (final f in _db.recentFiles(limit: 100000)) {
      if (f.size < minDuplicateSize || !_validator.isAllowed(f.path)) continue;
      if (f.path.contains(quarantineFolderName)) continue;
      (bySize[f.size] ??= []).add(f);
    }
    final copies = <String, String>{};
    for (final group in bySize.values) {
      if (group.length < 2) continue;
      final byHash = <String, List<IndexedFile>>{};
      for (final f in group) {
        final hash = await _hashOf(f.path);
        if (hash != null) (byHash[hash] ??= []).add(f);
      }
      for (final same in byHash.values) {
        if (same.length < 2) continue;
        same.sort((a, b) {
          final filedA = _isFiled(a.path) ? 0 : 1;
          final filedB = _isFiled(b.path) ? 0 : 1;
          if (filedA != filedB) return filedA - filedB;
          // Camera originals beat copies that landed in Downloads.
          final photoA = _inPhotoRoot(a.path) ? 0 : 1;
          final photoB = _inPhotoRoot(b.path) ? 0 : 1;
          if (photoA != photoB) return photoA - photoB;
          final age = a.modified.compareTo(b.modified);
          return age != 0 ? age : a.name.length.compareTo(b.name.length);
        });
        for (final copy in same.skip(1)) {
          copies[copy.path] = same.first.path;
        }
      }
    }
    return copies;
  }

  bool _inPhotoRoot(String path) {
    final root = _validator.rootOf(path);
    return root != null && photoRoots.contains(root);
  }

  /// In a sub-folder of an allowed folder (already organized).
  bool _isFiled(String path) {
    final root = _validator.rootOf(path);
    return root != null && !p.equals(p.dirname(path), root);
  }

  Future<String?> _hashOf(String path) async {
    final cached = _db.fileHash(path);
    if (cached != null) return cached;
    try {
      final hash = _fnv1a64(await File(path).readAsBytes());
      _db.saveFileHash(path, hash);
      return hash;
    } on FileSystemException {
      return null;
    }
  }

  /// 64-bit FNV-1a, enough to tell same-size files apart.
  static String _fnv1a64(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  Suggestion _duplicateSuggestion(
      String path, String root, String original, Set<String> claimed) {
    final target = uniqueTarget(
        p.join(root, quarantineFolderName, p.basename(path)), claimed);
    claimed.add(p.canonicalize(target));
    // "Download/receipt.jpg": the original's folder and name.
    final shown = '${p.basename(p.dirname(original))}/${p.basename(original)}';
    return Suggestion(
      id: newId(),
      type: ActionType.move,
      sourcePath: path,
      targetPath: target,
      reason: '$duplicatePrefix $shown. Held in quarantine, not deleted.',
      confidence: 0.99,
      category: quarantineFolderName,
    );
  }

  static const duplicatePrefix = 'Exact duplicate of';

  /// Tiny files (empty markers, .nomedia) are not worth flagging.
  static const minDuplicateSize = 1024;

  // --- Learned habits ----------------------------------------------------------

  static const learnedPrefix = 'Learned from your approvals';

  /// "2026-03_Meralco_Statement.pdf" → "issuer:meralco".
  static String? issuerKey(String fileName) {
    final m = RegExp(r'^\d{4}-\d{2}_([^_]+)_').firstMatch(fileName);
    return m == null ? null : 'issuer:${m[1]!.toLowerCase()}';
  }

  static String extKey(String fileName) =>
      'ext:${p.extension(fileName).toLowerCase()}';

  String? _habitFor(String? key) => key == null ? null : _db.habitFolder(key);

  /// The folder the user usually picks for this kind of file (issuer first,
  /// then extension), or null if nothing has been learned yet.
  String? learnedFolder(String fileName) =>
      _habitFor(issuerKey(fileName)) ?? _habitFor(extKey(fileName));

  /// Remember where an approved file went (relative to its allowed folder).
  void _learnFrom(String target) {
    final root = _validator.rootOf(target);
    if (root == null) return;
    final folder = p.relative(p.dirname(target), from: root).replaceAll(r'\', '/');
    if (folder == '.' || folder.startsWith('Quarantine')) return;
    final name = p.basename(target);
    _db.recordHabit(extKey(name), folder);
    final issuer = issuerKey(name);
    if (issuer != null) _db.recordHabit(issuer, folder);
  }

  // --- Single-file suggestion (camera) ---------------------------------------

  /// Suggestion for one new document photo (e.g. just taken with the camera):
  /// indexes it and proposes `Scans/` (or a house rule / learned folder). The
  /// caller runs OCR first so the photo counts as a confirmed document.
  Future<Suggestion?> suggestForDocument(String path) async {
    final file = File(path);
    final root = _validator.rootOf(path);
    if (root == null || !await file.exists()) return null;
    final stat = await file.stat();
    if (_db.file(path) == null) {
      _db.upsertFiles([(path, stat.size, stat.modified.millisecondsSinceEpoch)]);
    }
    final indexed = _db.file(path);
    final name = p.basename(path);
    final rule = houseRules.match(name, indexed?.ocrText);
    final learned = rule == null ? learnedFolder(name) : null;
    final category = rule?.folder ?? learned ?? photoCategory;
    final target = uniqueTarget(p.join(root, category, name));
    return Suggestion(
      id: newId(),
      type: ActionType.move,
      sourcePath: path,
      targetPath: target,
      reason: rule != null
          ? 'Your rule: "${rule.source}"'
          : 'Photo of a document → $category',
      confidence: rule != null ? 1.0 : 0.85,
      category: category,
      needsRename: true,
    );
  }

  /// Photo-folder policy: images from the last [photoWindow] that are (or
  /// may be) documents go to `Scans`; everything else is left alone.
  Suggestion? _photoSuggestion(
      File file, String root, IndexedFile? indexed, Set<String> claimed) {
    final name = p.basename(file.path);
    if (!RulesEngine.isImage(name)) return null;
    final modified = indexed?.modified ?? file.statSync().modified;
    if (DateTime.now().difference(modified) > photoWindow) return null;

    final text = indexed?.ocrText;
    final known = text != null;
    if (known && !RulesEngine.looksLikeDocument(text)) return null;

    final rule = houseRules.match(name, text);
    final category = rule?.folder ?? photoCategory;
    final aiName = known ? indexed?.aiName : null;
    final target = uniqueTarget(p.join(root, category, aiName ?? name), claimed);
    claimed.add(p.canonicalize(target));
    return Suggestion(
      id: newId(),
      type: ActionType.move,
      sourcePath: file.path,
      targetPath: target,
      reason: rule != null
          ? 'Your rule: "${rule.source}"'
          : 'Photo of a document → $category',
      confidence: rule != null ? 1.0 : 0.8,
      category: category,
      needsRename: aiName == null,
      aiNamed: aiName != null,
      needsDocumentCheck: !known,
    );
  }

  @override
  Future<ApplyResult> apply(List<Suggestion> approved) async {
    final batchId = newId();
    final applied = <ActionRecord>[];
    final rejected = <String, String>{};
    final claimed = <String>{};

    for (final s in approved) {
      final check = _validator.check(s, plannedTargets: claimed);
      if (!check.ok) {
        rejected[s.id] = check.reason!;
        continue;
      }
      try {
        if (s.type == ActionType.createFolder) {
          await Directory(s.targetPath).create();
          applied.add(_log(batchId, s.type, s.targetPath, s.targetPath));
        } else {
          // Create (and log) every missing folder level, outermost first, so
          // undo removes them innermost first once they are empty.
          final missing = <String>[];
          for (var dir = p.dirname(s.targetPath);
              !await Directory(dir).exists() && _validator.isAllowed(dir);
              dir = p.dirname(dir)) {
            missing.insert(0, dir);
          }
          for (final dir in missing) {
            await Directory(dir).create();
            applied.add(_log(batchId, ActionType.createFolder, dir, dir));
          }
          await moveFile(s.sourcePath, s.targetPath);
          _db.movePath(s.sourcePath, s.targetPath);
          applied.add(_log(batchId, s.type, s.sourcePath, s.targetPath));
          _learnFrom(s.targetPath);
        }
        claimed.add(p.canonicalize(s.targetPath));
      } on FileSystemException catch (e) {
        rejected[s.id] = e.message;
      }
    }
    return ApplyResult(batchId: batchId, applied: applied, rejected: rejected);
  }

  @override
  Future<UndoResult> undo(String actionId) async {
    final record = _db.action(actionId);
    if (record == null) {
      return UndoResult(undone: const [], failed: {actionId: 'Unknown action'});
    }
    final error = await _undoOne(record);
    return error == null
        ? UndoResult(undone: [record.markUndone()], failed: const {})
        : UndoResult(undone: const [], failed: {actionId: error});
  }

  @override
  Future<UndoResult> undoBatch(String batchId) async {
    final undone = <ActionRecord>[];
    final failed = <String, String>{};
    // Reverse order: files go back before the folders they were moved into
    // are removed.
    for (final r in _db.batch(batchId).reversed) {
      if (r.undone) continue;
      final error = await _undoOne(r);
      if (error == null) {
        undone.add(r.markUndone());
      } else {
        failed[r.id] = error;
      }
    }
    return UndoResult(undone: undone, failed: failed);
  }

  @override
  Future<ApplyResult> quarantine(String filePath) async {
    final root = _validator.rootOf(filePath);
    if (root == null) {
      return ApplyResult(
        batchId: '',
        applied: const [],
        rejected: {filePath: 'File is outside the allowed folders'},
      );
    }
    final target =
        uniqueTarget(p.join(root, quarantineFolderName, p.basename(filePath)));
    return apply([
      Suggestion(
        id: newId(),
        type: ActionType.move,
        sourcePath: filePath,
        targetPath: target,
        reason: 'Moved to quarantine',
        category: quarantineFolderName,
      ),
    ]);
  }

  @override
  Future<List<ActionRecord>> history() async => _db.actions();

  // --- Index, OCR cache and search -------------------------------------------

  /// Incrementally sync the index with the allowed folders. Only `stat`s
  /// files; new or changed files are written, unchanged ones are skipped, so
  /// cached OCR text and AI names survive.
  Future<IndexStats> refreshIndex() async {
    final known = _db.fileSignatures();
    final seen = <String>{};
    final changed = <(String, int, int)>[];

    for (final root in _validator.roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      final entries = dir
          .list(recursive: true, followLinks: false)
          .handleError((_) {}, test: (e) => e is FileSystemException);
      await for (final entity in entries) {
        if (entity is! File) continue;
        if (RulesEngine.isIgnored(p.basename(entity.path))) continue;
        final FileStat stat;
        try {
          stat = await entity.stat();
        } on FileSystemException {
          continue;
        }
        final path = entity.path;
        final mtime = stat.modified.millisecondsSinceEpoch;
        seen.add(path);
        final prev = known[path];
        if (prev == null || prev.$1 != stat.size || prev.$2 != mtime) {
          changed.add((path, stat.size, mtime));
        }
      }
    }

    // Forget files that disappeared from the allowed folders.
    final removed = known.keys
        .where((path) => !seen.contains(path) && _validator.isAllowed(path))
        .toList();

    if (changed.isNotEmpty) _db.upsertFiles(changed);
    if (removed.isNotEmpty) _db.removeFiles(removed);
    _indexedThisSession = true;
    return IndexStats(seen.length, changed.length, removed.length);
  }

  /// Scans/photos that still need OCR. The Flutter layer runs OCR (ML Kit)
  /// on these and reports back with [saveOcrText].
  List<IndexedFile> filesNeedingOcr({int limit = 50}) => _db
      .filesNeedingOcr(limit: limit)
      .where((f) => _validator.isAllowed(f.path))
      .toList();

  /// Cache OCR text so it is searchable and never recomputed for this file.
  /// Pass '' when no text was found.
  void saveOcrText(String path, String text) => _db.saveOcrText(path, text);

  /// Cached OCR text, or null if the file has not been OCR'd.
  String? ocrTextFor(String path) => _db.file(path)?.ocrText;

  /// Forget cached OCR text, AI names and the action history (the privacy
  /// panel's "wipe AI memory & logs"). Files are not touched, but past
  /// actions can no longer be undone.
  void wipeMemory() => _db.wipe();

  @override
  Future<List<FileResult>> search(String query) =>
      searchWith(SearchQuery.parse(query));

  /// Search with already-structured filters (e.g. produced by the LLM).
  Future<List<FileResult>> searchWith(SearchQuery query, {int limit = 50}) async {
    if (query.isEmpty) return const [];
    if (!_indexedThisSession) await refreshIndex();

    final candidates = query.keywords.isNotEmpty
        ? _db.searchText(query.keywords)
        : _db.recentFiles();

    final results = <FileResult>[];
    for (final f in candidates) {
      if (!_validator.isAllowed(f.path)) continue;
      final dateReasons = query.matchDate(f.name, f.modified,
          documentDate: _documentDate(query, f));
      if (dateReasons == null) continue;
      results.add(FileResult(
        path: f.path,
        sizeBytes: f.size,
        modified: f.modified,
        matchReason: [
          if (query.keywords.isNotEmpty) _keywordReason(query.keywords, f),
          ...dateReasons,
        ].join(', '),
      ));
      if (results.length >= limit) break;
    }
    return results;
  }

  static final _dates = DateExtractor();

  /// The date printed inside a scanned document (from its OCR text), only
  /// computed when the query filters by month or year.
  static DateTime? _documentDate(SearchQuery query, IndexedFile f) {
    if (query.month == null && query.year == null) return null;
    final text = f.ocrText;
    if (text == null || text.isEmpty) return null;
    final d = _dates.extract(text);
    return d == null ? null : DateTime(d.year, d.month, d.day ?? 1);
  }

  static String _keywordReason(List<String> keywords, IndexedFile f) {
    final name = f.name.toLowerCase();
    final words = keywords.join(' ');
    return keywords.every(name.contains)
        ? 'name has "$words"'
        : 'document text mentions "$words"';
  }

  // --- Privacy ---------------------------------------------------------------

  @override
  Stream<bool> get isOffline => offlineStatus();

  // ---------------------------------------------------------------------------

  ActionRecord _log(
      String batchId, ActionType type, String source, String target) {
    final record = ActionRecord(
      id: newId(),
      batchId: batchId,
      type: type,
      sourcePath: source,
      targetPath: target,
      timestamp: DateTime.now(),
    );
    _db.addAction(record);
    return record;
  }

  /// Returns null on success, otherwise why the undo could not happen.
  Future<String?> _undoOne(ActionRecord r) async {
    if (r.undone) return 'Already undone';
    try {
      if (r.type == ActionType.createFolder) {
        // Only remove the folder if it is still empty; never delete content.
        final dir = Directory(r.targetPath);
        if (await dir.exists() && await dir.list().isEmpty) {
          await dir.delete();
        }
      } else {
        if (!await File(r.targetPath).exists()) {
          return 'The file was moved or removed since';
        }
        if (pathExists(r.sourcePath)) {
          return 'Another file now uses the original name';
        }
        await Directory(p.dirname(r.sourcePath)).create(recursive: true);
        await moveFile(r.targetPath, r.sourcePath);
        _db.movePath(r.targetPath, r.sourcePath);
      }
      _db.markUndone(r.id);
      return null;
    } on FileSystemException catch (e) {
      return e.message;
    }
  }
}
