import 'dart:async';
import 'dart:io';

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

    for (final folder in _validator.roots) {
      final dir = Directory(folder);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final match = _rules.classify(name);
        if (match == null) continue;

        // Reuse a cached AI name so rescans are instant.
        final aiName = match.needsRename ? _db.file(entity.path)?.aiName : null;
        final target = uniqueTarget(
            p.join(folder, match.category, aiName ?? name), claimed);
        claimed.add(p.canonicalize(target));
        suggestions.add(Suggestion(
          id: newId(),
          type: ActionType.move,
          sourcePath: entity.path,
          targetPath: target,
          reason: aiName != null
              ? 'Named from its content → ${match.category}'
              : match.reason,
          confidence: match.confidence,
          category: match.category,
          needsRename: match.needsRename && aiName == null,
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
      final target =
          uniqueTarget(p.join(p.dirname(s.targetPath), newName), claimed);
      claimed.add(p.canonicalize(target));

      yield Suggestion(
        id: s.id,
        type: s.type,
        sourcePath: s.sourcePath,
        targetPath: target,
        reason: s.category == null ? reason : '$reason → ${s.category}',
        confidence: confidence,
        category: s.category,
        aiNamed: true,
      );
    }
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
          final parent = p.dirname(s.targetPath);
          if (!await Directory(parent).exists()) {
            await Directory(parent).create(recursive: true);
            applied.add(_log(batchId, ActionType.createFolder, parent, parent));
          }
          await moveFile(s.sourcePath, s.targetPath);
          _db.movePath(s.sourcePath, s.targetPath);
          applied.add(_log(batchId, s.type, s.sourcePath, s.targetPath));
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
