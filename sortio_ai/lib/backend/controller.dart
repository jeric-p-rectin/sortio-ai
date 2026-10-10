// ============================================================================
// Sortio AI — backend/controller.dart
//
// SortioController — ALL app state & behaviour (the on-device agent logic):
// offline mode, suggestion approve/edit/ignore/undo, folder permissions,
// strictness, house rules, session switching, chat, toasts and the two-tap
// memory wipe. Screens listen to this ChangeNotifier and rebuild.
//
// Backed by the on-device engine (sortio_core.dart): real scan, apply, undo,
// quarantine, search and offline status. If the engine cannot start (widget
// tests, web, missing plugins) it falls back to the scripted demo data.
// ============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data_output.dart';
import 'design_tokens.dart';
import 'llm/llamadart_client.dart';
import 'models.dart';
import 'motion.dart';
import 'platform/model_store.dart';
import 'platform/ocr_service.dart';
import 'sortio_core.dart' as core;

/// Which location the app starts on (mirrors the prototype's `startPanel`
/// prop: none | settings).
enum StartPanel { none, settings }

class SortioController extends ChangeNotifier {
  SortioController() {
    if (Platform.isAndroid) {
      // Real device: show nothing until the on-device data is loaded, so the
      // demo chats and files never flash on screen at startup.
      SortioData.liveFiles = const [];
      SortioData.liveChats = chatSessions;
    } else {
      _seedChats(); // desktop/tests: the scripted demo
    }
    unawaited(_init());
  }

  /// Seeds the chat history with the scripted demo conversation and a few
  /// past chats; the demo chat is the one open in the chat screen.
  void _seedChats() {
    chatSessions
      ..clear()
      ..addAll(SortioData.demoChatSessions());
    activeSession = chatSessions.isEmpty ? null : chatSessions.first;
  }

  // --- Core state -----------------------------------------------------------
  bool offline = false;

  String toastText = '';
  bool toastOn = false;

  /// id -> suggestion (insertion-ordered, as shown in the feed).
  final Map<String, Suggestion> suggestions = {};

  String? editingId;
  String draft = '';
  bool copied = false;

  Map<String, FolderAccess> _folders = {
    for (final f in SortioData.folders()) f.key: f,
  };
  bool armed = false;

  // --- Appearance ------------------------------------------------------------
  /// True while the dark palette is active (the app's original look).
  bool darkMode = true;

  // --- AI strictness & house rules -------------------------------------------
  /// How sure the AI must be before a suggestion counts as a recommendation:
  /// 0.0 (lenient) to 1.0 (strict). Less-sure cards stay amber questions.
  double strictness = 0.5;

  /// The user's plain-language house rules ("Always file Zoom receipts under
  /// Finance"), parsed by the engine.
  String rules = '';

  /// Minimum confidence, in percent, derived from [strictness] (50% to 90%).
  ({int threshold}) get strictOutput =>
      (threshold: (50 + strictness.clamp(0.0, 1.0) * 40).round());

  /// All chats, newest first — drives the History (chats) screen.
  final List<ChatSession> chatSessions = <ChatSession>[];

  /// The conversation currently open in the chat screen. Null while a brand
  /// new chat has no messages yet (the feed shows a welcome state).
  ChatSession? activeSession;

  /// True while the scripted demo conversation is the one on screen — its
  /// suggestion cards belong to that conversation only.
  bool get isScriptedChat => activeSession?.id == _cardsSessionId;

  /// The chat that owns the suggestion cards: the seeded demo chat at start,
  /// then whichever chat last asked Sortio to tidy (its scan fills the cards).
  String _cardsSessionId = SortioData.scriptedChatId;

  bool typing = false;
  String? typingSessionId;
  String composerText = '';

  /// True while the engine is scanning (no "done" line yet).
  bool scanning = true;

  Timer? _toastTimer;
  Timer? _armTimer;
  Timer? _copyTimer;
  Timer? _replyTimer;
  final List<Timer> _timers = <Timer>[];

  // --- Engine ---------------------------------------------------------------
  core.LocalSortioCore? _engine;
  OcrService? _ocr;
  LlamaDartClient? _llm;
  Future<void>? _modelReady;
  bool settingUpModel = false;

  final Map<String, core.ContentInsights> _insightsById = {};
  int _scanGeneration = 0;
  bool aiBusy = false;
  StreamSubscription<bool>? _offlineSub;
  bool? _lastRealOffline;
  bool _disposed = false;

  /// UI suggestion id -> engine suggestion, and -> batch id once applied.
  final Map<String, core.Suggestion> _engineById = {};
  final Map<String, String> _batchById = {};
  // Real numbers come from the action history once the engine is open;
  // until then show zeros, never the demo figures.
  SavingsSummary _savings = const SavingsSummary(files: 0, mbFreed: 0, minutesSaved: 0);

  /// True when the real on-device engine is running (not demo data).
  bool get engineReady => _engine != null;

  Future<void> _init() async {
    try {
      final dataDir = (await getApplicationSupportDirectory()).path;
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        if (!status.isGranted) _toast(SortioData.permissionHint);
      }
      if (_disposed) return;
      _engine = core.LocalSortioCore(dataDir: dataDir);
      _loadChats();
      _loadRules();
      final savedTemplate = _engine!.db.setting(_templateKey);
      if (savedTemplate == null || _isValidTemplate(savedTemplate)) {
        namingTemplate = savedTemplate ?? core.NameBuilder.defaultTemplate;
      } else {
        // A broken template from an older build: reset it and rebuild names.
        _engine!.db.saveSetting(_templateKey, core.NameBuilder.defaultTemplate);
        _engine!.db.clearAiNames();
      }
      _ocr = OcrService(tempDir: (await getTemporaryDirectory()).path);
      _modelReady = _prepareModel(dataDir);
      _offlineSub = _engine!.isOffline.listen(_onRealOffline);
      await _rescan();
      await _refreshSavings();
    } on Object catch (e) {
      debugPrint('Sortio engine unavailable, using demo data: $e');
      _loadDemo();
    }
  }

  /// First launch copies the model out of the APK (~15 s); scanning and OCR
  /// run meanwhile, and the AI rename step waits for this.
  Future<void> _prepareModel(String dataDir) async {
    final store = ModelStore(dataDir);
    if (store.find() == null) {
      settingUpModel = true;
      _notify();
    }
    try {
      final modelPath = await store.ensureInstalled();
      if (modelPath != null && !_disposed) _llm = LlamaDartClient(modelPath);
      debugPrint('Sortio on-device model: ${modelPath ?? 'not installed'}');
    } finally {
      settingUpModel = false;
      _notify();
    }
  }

  void _loadDemo() {
    if (_disposed) return;
    suggestions
      ..clear()
      ..addEntries(
        SortioData.initialSuggestions().map((s) => MapEntry(s.id, s)),
      );
    scanning = false;
    _notify();
  }

  void _onRealOffline(bool isOffline) {
    if (_lastRealOffline == isOffline) return;
    _lastRealOffline = isOffline;
    offline = isOffline;
    _notify();
  }

  List<String> get _allowedRoots => [
    for (final f in _folders.values)
      if (f.allowed)
        for (final dir in SortioData.folderDirs[f.key] ?? [f.label])
          p.normalize(p.join(SortioData.storageRoot, dir)),
  ];

  /// Allowed roots that hold photos (camera roll, pictures, screenshots).
  Set<String> get _photoRoots => {
    for (final f in _folders.values)
      if (f.allowed && SortioData.photoFolderKeys.contains(f.key))
        for (final dir in SortioData.folderDirs[f.key]!)
          p.normalize(p.join(SortioData.storageRoot, dir)),
  };

  /// "/storage/emulated/0/Download/a.pdf" → "Download/a.pdf"
  static String _display(String path) {
    const root = '${SortioData.storageRoot}/';
    return path.startsWith(root) ? path.substring(root.length) : path;
  }

  static String _absolute(String displayPath) => displayPath.startsWith('/')
      ? displayPath
      : p.join(SortioData.storageRoot, displayPath);

  /// Engine suggestion → the card model the screens render.
  Suggestion _toCard(core.Suggestion s) {
    final quarantine = s.category == core.LocalSortioCore.quarantineFolderName;
    final renamed = s.fileName != s.targetName;
    final insights = _insightsById[s.id];
    final hasExtract = insights?.amountValue != null;
    final percent = (s.confidence * 100).round();
    final threshold = strictOutput.threshold;
    final unsure = !quarantine && percent < threshold;
    return Suggestion(
      id: s.id,
      kind: quarantine
          ? 'Quarantine'
          : [
              if (renamed) 'Rename',
              'Move',
              if (hasExtract) 'Extract',
            ].join(' · '),
      fromPath: _display(s.sourcePath),
      toPath: _display(s.targetPath),
      tone: quarantine || unsure ? SuggestionTone.amber : SuggestionTone.cyan,
      badge: insights?.sensitiveBadge,
      extractLabel: hasExtract ? insights!.amountLabel : null,
      extractValue: hasExtract ? insights!.amountValue : null,
      reason: quarantine ||
              s.reason.startsWith(SortioData.houseRulePrefix) ||
              s.reason.contains(core.LocalSortioCore.learnedPrefix)
          ? s.reason
          : unsure
          ? SortioData.lowConfidenceReason(percent, threshold)
          : null,
    );
  }

  /// Rebuild pending cards (e.g. after the strictness setting changed).
  void _refreshCards() {
    for (final s in _engineById.values.toList()) {
      _replaceCard(s);
    }
  }

  // --- Persistent chats -------------------------------------------------------

  /// Restores saved chats; on first launch creates the welcome chat that
  /// reports the first scan (its cards live there).
  void _loadChats() {
    final engine = _engine;
    if (engine == null) return;
    chatSessions
      ..clear()
      ..addAll([
        for (final c in engine.db.chats())
          ChatSession(
            id: c.id,
            title: c.title,
            updatedAt: c.updatedAt,
            messages: [
              for (final m in c.messages)
                ChatMessage(id: m.id, isUser: m.isUser, text: m.text),
            ],
          ),
      ]);
    final firstLaunch = engine.db.setting(_welcomeKey) == null;
    if (firstLaunch && !chatSessions.any((c) => c.id == SortioData.scriptedChatId)) {
      final welcome = ChatSession(
        id: SortioData.scriptedChatId,
        title: SortioData.welcomeTitle,
        updatedAt: DateTime.now(),
        messages: const [
          ChatMessage(id: 'w1', isUser: false, text: SortioData.welcomeLine),
          ChatMessage(id: 'w2', isUser: false, text: SortioData.scanningLine),
        ],
      );
      chatSessions.insert(0, welcome);
      for (final m in welcome.messages) {
        _persistMessage(welcome, m);
      }
      engine.db.saveSetting(_welcomeKey, '1');
    }
    _cardsSessionId = SortioData.scriptedChatId;
    activeSession = chatSessions.isEmpty
        ? null // brand-new chat welcome state
        : chatSessions.firstWhere(
            (c) => c.id == SortioData.scriptedChatId,
            orElse: () => chatSessions.first,
          );
    SortioData.liveChats = chatSessions; // same list: Home sees new chats too
    _notify();
  }

  /// Saves the chat row and one of its messages (insert or update).
  void _persistMessage(ChatSession chat, ChatMessage m) {
    final db = _engine?.db;
    if (db == null) return;
    db.saveChat(chat.id, chat.title, chat.updatedAt);
    db.saveMessage(
      chat.id,
      core.StoredMessage(
        id: m.id,
        isUser: m.isUser,
        text: m.text,
        at: DateTime.now(),
      ),
    );
  }

  // --- House rules -----------------------------------------------------------

  static const _rulesKey = 'house_rules';
  static const _templateKey = 'name_template';

  /// How AI names are built, e.g. "{date}_{issuer}_{type}". Saved on device.
  String namingTemplate = core.NameBuilder.defaultTemplate;
  static const _welcomeKey = 'welcome_shown';
  Timer? _rulesTimer;

  void _loadRules() {
    final engine = _engine;
    if (engine == null) return;
    rules = engine.db.setting(_rulesKey) ?? '';
    engine.houseRules = core.HouseRules.parse(rules);
  }

  /// Saves the rules and re-scans once the user stops typing.
  void _applyRulesSoon() {
    _rulesTimer?.cancel();
    _rulesTimer = Timer(const Duration(milliseconds: 1200), () {
      final engine = _engine;
      if (engine == null || _disposed) return;
      engine.db.saveSetting(_rulesKey, rules);
      final parsed = core.HouseRules.parse(rules);
      final before = engine.houseRules.rules.map((r) => r.source).join('|');
      engine.houseRules = parsed;
      if (parsed.rules.map((r) => r.source).join('|') == before) return;
      _toast(SortioData.rulesApplied(parsed.rules.length));
      unawaited(_rescan());
    });
  }

  /// Swap a pending card for an updated one, keeping its place in the feed.
  void _replaceCard(core.Suggestion s) {
    final card = suggestions[s.id];
    if (card == null || !card.isPending || card.closing || editingId == s.id) {
      return;
    }
    _engineById[s.id] = s;
    suggestions[s.id] = _toCard(s);
    _notify();
  }

  /// After a scan: OCR every scan (amount + sensitive badge, searchable
  /// text), then let the on-device model name them. Cards update one by one.
  Future<void> _runAi() async {
    final engine = _engine;
    final ocr = _ocr;
    if (engine == null || ocr == null) return;
    final generation = _scanGeneration;
    bool stale() => _disposed || generation != _scanGeneration;

    // Scans still to be named, plus ones already named from the cache (they
    // still need their amount / sensitive badge on the card).
    final checks = [
      for (final s in _engineById.values)
        if (s.needsDocumentCheck) s,
    ];
    final scans = [
      for (final s in _engineById.values)
        if (!s.needsDocumentCheck && (s.needsRename || s.aiNamed)) s,
    ];
    if (scans.isEmpty && checks.isEmpty) return;
    aiBusy = true;
    _notify();
    try {
      // Photos: OCR decides. Documents get a card; ordinary photos are
      // dropped silently and never touched.
      for (final s in checks) {
        if (stale()) return;
        var text = engine.ocrTextFor(s.sourcePath);
        if (text == null) {
          try {
            text = await ocr.read(s.sourcePath);
          } on Object catch (e) {
            debugPrint('OCR failed for ${s.sourcePath}: $e');
            text = '';
          }
          engine.saveOcrText(s.sourcePath, text);
        }
        if (stale()) return;
        if (!core.RulesEngine.looksLikeDocument(text)) {
          _engineById.remove(s.id);
          continue;
        }
        final confirmed = s.copyWith(needsDocumentCheck: false);
        _engineById[s.id] = confirmed;
        suggestions[s.id] = _toCard(confirmed);
        scans.add(confirmed);
        _notify();
      }

      for (final s in scans) {
        if (stale()) return;
        var text = engine.ocrTextFor(s.sourcePath);
        if (text == null) {
          try {
            text = await ocr.read(s.sourcePath);
          } on Object catch (e) {
            debugPrint('OCR failed for ${s.sourcePath}: $e');
            text = '';
          }
          engine.saveOcrText(s.sourcePath, text);
        }
        if (stale()) return;
        _insightsById[s.id] = core.ContentInsights.fromText(text);
        _replaceCard(_engineById[s.id] ?? s);
      }

      await _modelReady;
      if (stale()) return;
      final llm = _llm;
      if (llm == null) return;
      await for (final named in engine.aiRename(
        scans,
        core.RenameService(llm, names: core.NameBuilder(template: namingTemplate)),
      )) {
        if (stale()) return;
        _replaceCard(named);
      }
    } on Object catch (e) {
      debugPrint('Sortio AI step failed: $e');
    } finally {
      if (generation == _scanGeneration) {
        aiBusy = false;
        _notify();
        unawaited(_publishLiveData());
      }
    }
  }

  Future<void> _rescan({bool Function(core.Suggestion s)? only}) async {
    final engine = _engine;
    if (engine == null) return;
    scanning = true;
    final generation = ++_scanGeneration;
    _notify();
    engine.photoRoots = _photoRoots;
    final scanned = await engine.scan(_allowedRoots);
    final found = only == null ? scanned : scanned.where(only).toList();
    if (_disposed || generation != _scanGeneration) return;
    suggestions.clear();
    _engineById.clear();
    _batchById.clear();
    _insightsById.clear();
    for (final s in found.where((s) => !s.needsDocumentCheck).take(25)) {
      _engineById[s.id] = s;
      suggestions[s.id] = _toCard(s);
    }
    // Recent photos that may be documents: no card until OCR confirms it.
    for (final s in found.where((s) => s.needsDocumentCheck).take(25)) {
      _engineById[s.id] = s;
    }
    scanning = false;
    _syncDemoReply();
    _notify();
    unawaited(_publishLiveData());
    unawaited(_runAi());
  }

  /// The seeded demo chat says what the real scan found, instead of the
  /// prototype's scripted "Found your bill and 2 other files".
  void _syncDemoReply() {
    if (_cardsSessionId != SortioData.scriptedChatId) return;
    for (final chat in chatSessions) {
      if (chat.id != SortioData.scriptedChatId || chat.messages.length < 2) {
        continue;
      }
      final seeded = chat.messages[1];
      if (seeded.isUser) return;
      chat.messages[1] = ChatMessage(
        id: seeded.id,
        isUser: false,
        text: SortioData.scanReply(suggestions.length, visibleFolderNames),
      );
      _persistMessage(chat, chat.messages[1]);
      return;
    }
  }

  Future<void> _refreshSavings() async {
    final engine = _engine;
    if (engine == null) return;
    final history = await engine.history();
    var files = 0;
    var quarantinedBytes = 0;
    for (final a in history) {
      if (a.undone || a.type == core.ActionType.createFolder) continue;
      files++;
      if (a.targetPath.contains(core.LocalSortioCore.quarantineFolderName)) {
        final f = File(a.targetPath);
        if (f.existsSync()) quarantinedBytes += f.lengthSync();
      }
    }
    _savings = SavingsSummary(
      files: files,
      mbFreed: (quarantinedBytes / (1024 * 1024)).round(),
      minutesSaved: (files * 0.5).ceil(),
    );
    _notify();
    await _publishLiveData();
  }

  // --- Live History / Files data ------------------------------------------------

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  static FileKind _kind(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext == '.pdf') return FileKind.pdf;
    if (const {
      '.exe',
      '.msi',
      '.bat',
      '.cmd',
      '.apk',
      '.jar',
      '.scr',
    }.contains(ext)) {
      return FileKind.exe;
    }
    if (const {
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.bmp',
    }.contains(ext)) {
      return FileKind.image;
    }
    return FileKind.doc;
  }

  /// Which File Manager group a path belongs to.
  static String? _folderKeyFor(String path) {
    if (path.contains('/${core.LocalSortioCore.quarantineFolderName}/')) {
      return 'quarantine';
    }
    for (final entry in SortioData.folderDirs.entries) {
      for (final dir in entry.value) {
        if (p.isWithin(p.join(SortioData.storageRoot, dir), path)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Rebuilds the File Manager data from the engine's file index (with
  /// OCR-based sensitive flags and pending-suggestion markers).
  Future<void> _publishLiveData() async {
    final engine = _engine;
    if (engine == null || _disposed) return;

    final pendingSources = {
      for (final s in _engineById.entries)
        if (suggestions[s.key]?.isPending ?? false) s.value.sourcePath,
    };
    // Newest files per folder, so a big camera roll never crowds out
    // Downloads or Documents.
    const perFolder = 200;
    final files = <FileItem>[];
    final seen = <String>{};
    final perKey = <String, int>{};
    final indexed = [
      for (final dirs in SortioData.folderDirs.values)
        for (final dir in dirs)
          ...engine.db.recentFilesUnder(
            p.join(SortioData.storageRoot, dir),
            limit: perFolder,
          ),
    ];
    for (final f in indexed) {
      if (!seen.add(f.path)) continue; // Pictures/Screenshots is inside Pictures
      final key = _folderKeyFor(f.path);
      if (key == null) continue;
      final count = perKey[key] = (perKey[key] ?? 0) + 1;
      if (count > perFolder) continue;
      final text = f.ocrText;
      files.add(
        FileItem(
          folderKey: key,
          name: f.name,
          size: _size(f.size),
          modified: '${_months[f.modified.month - 1]} ${f.modified.day}',
          kind: _kind(f.name),
          sensitive:
              text != null &&
              text.isNotEmpty &&
              core.ContentInsights.fromText(text).isSensitive,
          suggested: pendingSources.contains(f.path),
        ),
      );
    }
    SortioData.liveFiles = files;
    _notify();
  }

  // --- Derived output -------------------------------------------------------
  List<FolderAccess> get folders => _folders.values.toList(growable: false);
  int get allowedFolderCount => _folders.values.where((f) => f.allowed).length;
  String get folderCount => '$allowedFolderCount of 3 allowed';
  List<String> get visibleFolderNames => _folders.values
      .where((f) => f.allowed)
      .map((f) => f.label)
      .toList(growable: false);

  List<Suggestion> get pendingSuggestions =>
      suggestions.values.where((s) => s.isPending).toList(growable: false);
  bool get allResolved =>
      !scanning && suggestions.values.every((s) => !s.isPending);
  int get appliedCount => suggestions.values
      .where((s) => s.state == SuggestionState.applied)
      .length;
  String get doneLine => SortioData.doneLine(appliedCount, suggestions.length);

  SavingsSummary get savings => _savings;

  /// Approve or ignore a suggestion: collapse the card first (380 ms), then
  /// swap in the applied/ignored row — same sequencing as the prototype.
  /// Approving applies the change for real through the engine's validator.
  Future<void> resolve(String id, SuggestionState outcome) async {
    final s = suggestions[id];
    if (s == null || s.closing || !s.isPending) return;
    s.closing = true;
    _notify();

    final engine = _engine;
    final planned = _engineById[id];
    if (outcome == SuggestionState.applied &&
        engine != null &&
        planned != null) {
      final result = await engine.apply([planned]);
      if (result.rejected.isNotEmpty) {
        s.closing = false;
        _toast('Not applied: ${result.rejected.values.first}');
        return;
      }
      _batchById[id] = result.batchId;
      unawaited(_refreshSavings());
    }

    _later(SortioMotion.resolveDelay, () {
      s
        ..closing = false
        ..state = outcome;
      _notify();
    });
  }

  Future<void> undo(String id) async {
    final s = suggestions[id];
    if (s == null) return;
    final was = s.state;

    final engine = _engine;
    final batchId = _batchById[id];
    if (was == SuggestionState.applied && engine != null && batchId != null) {
      final result = await engine.undoBatch(batchId);
      if (result.failed.isNotEmpty) {
        _toast('Could not undo: ${result.failed.values.first}');
        return;
      }
      _batchById.remove(id);
      unawaited(_refreshSavings());
    }

    s.state = SuggestionState.pending;
    _toast(
      was == SuggestionState.applied
          ? 'Undone. ${s.fromPath.split('/').last} is back where it was, exactly as it was.'
          : 'Suggestion restored. Nothing has been changed yet.',
    );
  }

  void startEdit(String id) {
    final s = suggestions[id];
    if (s == null) return;
    editingId = id;
    draft = s.toPath;
    _notify();
  }

  void cancelEdit() {
    editingId = null;
    _notify();
  }

  void setDraft(String value) {
    draft = value;
    _notify();
  }

  void saveEdit() {
    final id = editingId;
    if (id == null) return;
    final v = draft.trim();
    if (v.isNotEmpty) {
      final card = suggestions[id]!;
      final fileName = card.fromPath.split('/').last;
      final destination = v.endsWith('/') ? '$v$fileName' : v;
      card.toPath = destination;
      final planned = _engineById[id];
      if (planned != null) {
        _engineById[id] = planned.copyWith(targetPath: _absolute(destination));
      }
      _toast('Destination updated. Approve when you are ready.');
    } else {
      _toast('Path unchanged.');
    }
    editingId = null;
    _notify();
  }

  void setComposerText(String value) {
    composerText = value;
    _notify();
  }

  static final _duplicateIntent = RegExp(
    r'\b(duplicates?|dupes?|copies|doble|dobleng|kapareho)\b',
    caseSensitive: false,
  );
  static final _templateIntent = RegExp(
    r'(?:naming|name|file\s*name)\s*(?:template|format|style|pattern)\s*(?:to|:|=|as)?\s*(.*)$',
    caseSensitive: false,
  );
  static final _learnedIntent = RegExp(
    r'\b(what did you learn|what have you learned|habits|natutunan)\b',
    caseSensitive: false,
  );

  /// Only {date}, {issuer} and {type} placeholders, every brace closed.
  static bool _isValidTemplate(String template) =>
      template.contains('{') &&
      RegExp(r'^(?:[^{}]|\{(?:date|issuer|type)\})+$').hasMatch(template);

  /// Validates and saves a naming template; AI names are rebuilt with it.
  Future<String> _setNamingTemplate(String template) async {
    final engine = _engine;
    if (engine == null) return SortioData.templateHelp;
    final example = core.NameBuilder(template: template)
        .build(date: '2026-03', issuer: 'Meralco', type: 'Bill', extension: '.pdf');
    if (!_isValidTemplate(template) || example == null || example == 'Bill.pdf') {
      return SortioData.templateHelp;
    }
    namingTemplate = template;
    engine.db.saveSetting(_templateKey, template);
    engine.db.clearAiNames();
    unawaited(_rescan());
    return SortioData.templateSet(template, example);
  }

  static final _tidyIntent = RegExp(
    r'\b(tidy|organi[sz]e|clean|sort|scan|ayusin|ayos|linisin|i-?organize)\b',
    caseSensitive: false,
  );

  /// The chat list title for a new conversation: its first message.
  static String _titleFor(String text) {
    final t = text.replaceAll('\n', ' ').trim();
    return t.length > 48 ? '${t.substring(0, 48)}…' : t;
  }

  Future<void> sendMessage() async {
    final text = composerText.trim();
    if (text.isEmpty) {
      _toast(SortioData.emptyMessageHint);
      return;
    }

    var session = activeSession;
    if (session == null) {
      // First message of a brand-new chat: create its session and put it at
      // the top of the history.
      session = ChatSession(
        id: 'chat${DateTime.now().microsecondsSinceEpoch}',
        title: _titleFor(text),
        updatedAt: DateTime.now(),
      );
      chatSessions.insert(0, session);
      activeSession = session;
    }

    final sentAt = DateTime.now();
    final userMessage = ChatMessage(
      id: 'u${sentAt.microsecondsSinceEpoch}',
      isUser: true,
      text: text,
    );
    session
      ..updatedAt = sentAt
      ..messages.add(userMessage);
    _persistMessage(session, userMessage);
    composerText = '';
    typing = true;
    typingSessionId = session.id;
    _notify();

    final engine = _engine;
    String reply;
    if (engine == null) {
      await Future<void>.delayed(SortioMotion.agentThinking);
      reply = SortioData.agentReply(visibleFolderNames);
    } else if (visibleFolderNames.isEmpty) {
      reply = SortioData.agentReply(visibleFolderNames);
    } else {
      reply = await _respond(text, session, engine);
    }
    if (_disposed) return;

    _finishReply(session, reply);
  }

  // --- Chat understanding -------------------------------------------------------
  //
  // Keywords first (instant, English + Tagalog). When nothing matches, the
  // on-device model picks the intent from a fixed list (grammar-constrained,
  // so it cannot invent actions). Search is the last resort.

  static final _undoIntent = RegExp(
    r'\b(undo|ibalik|bawiin|revert|i-?undo)\b',
    caseSensitive: false,
  );
  static final _approveIntent = RegExp(
    r"\b(approve|approved|apply|go ahead|sige|tuloy|do it|i-?approve|okay na|ok na|yes|oo)\b",
    caseSensitive: false,
  );
  static final _ignoreIntent = RegExp(
    r"\b(ignore|skip|reject|huwag|wag na|cancel|no thanks)\b",
    caseSensitive: false,
  );
  static final _searchIntent = RegExp(
    r'\b(find|search|where|hanapin|hanap|nasaan|asan|saan|look for|show me|locate)\b',
    caseSensitive: false,
  );
  static final _explainIntent = RegExp(
    r"\b(about|summar(y|ize|ise)|explain|describe|what does (it|this|that) say|"
    r"what('?s| is) (in|inside)|contents?|laman|tungkol|buod|ibig sabihin|"
    r"i-?explain|basahin)\b",
    caseSensitive: false,
  );
  static final _thanksIntent = RegExp(
    r'\b(thanks|thank you|salamat|ty)\b',
    caseSensitive: false,
  );
  static final _helpIntent = RegExp(
    r"^\s*(hi|hello|hey|yo|kumusta|musta|good (morning|afternoon|evening))\b|\b(help|tulong|what can you do|ano (ang )?kaya mo|paano)\b",
    caseSensitive: false,
  );

  /// The intent from keywords alone, or null when unsure.
  String? _ruleIntent(String text) {
    if (_duplicateIntent.hasMatch(text)) return 'duplicates';
    if (_templateIntent.hasMatch(text)) return 'template';
    if (_learnedIntent.hasMatch(text)) return 'learned';
    if (_undoIntent.hasMatch(text)) return 'undo';
    if (_explainIntent.hasMatch(text)) return 'explain';
    if (_searchIntent.hasMatch(text)) return 'search';
    if (_tidyIntent.hasMatch(text)) return 'tidy';
    if (_ignoreIntent.hasMatch(text)) return 'ignore_all';
    if (_approveIntent.hasMatch(text)) return 'approve_all';
    if (_thanksIntent.hasMatch(text)) return 'thanks';
    if (_helpIntent.hasMatch(text)) return 'help';
    return null;
  }

  /// "sa photos" / "in my downloads" → folder key.
  static String? _folderIn(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(download|downloads)\b').hasMatch(t)) return 'downloads';
    if (RegExp(r'\b(photos?|pictures?|camera|gallery|litrato|larawan|screenshots?)\b').hasMatch(t)) {
      return 'photos';
    }
    if (RegExp(r'\b(documents?|docs|dokumento)\b').hasMatch(t)) return 'documents';
    return null;
  }

  static const _aiRouteTimeout = Duration(seconds: 8);

  /// Ask the on-device model what the user wants (null if it is unavailable).
  Future<({String intent, String? folder, String query})?> _aiRoute(String text) async {
    await _modelReady;
    final llm = _llm;
    if (llm == null) return null;
    try {
      // Never keep the user waiting: if the model is busy (e.g. naming
      // scans) or slow, fall back to search after a few seconds.
      final json = await llm
          .completeJson(
            system: core.routerSystemPrompt,
            user: text,
            schema: core.routerSchema,
          )
          .timeout(_aiRouteTimeout);
      final intent = json['intent'] as String?;
      if (intent == null || !core.chatIntents.contains(intent)) return null;
      final folder = json['folder'] as String?;
      return (
        intent: intent,
        folder: folder == null || folder == 'any' ? null : folder,
        query: (json['query'] as String? ?? '').trim(),
      );
    } on Object catch (e) {
      debugPrint('Chat routing fell back to search: $e');
      return null;
    }
  }

  bool _inFolder(String path, String key) => [
        for (final dir in SortioData.folderDirs[key] ?? const <String>[])
          p.join(SortioData.storageRoot, dir),
      ].any((root) => p.isWithin(root, path));

  Future<String> _respond(
    String text,
    ChatSession session,
    core.LocalSortioCore engine,
  ) async {
    var intent = _ruleIntent(text);
    var folder = _folderIn(text);
    var query = text;
    if (intent == null) {
      final routed = await _aiRoute(text);
      intent = routed?.intent ?? 'search';
      folder ??= routed?.folder;
      if (routed != null && routed.query.isNotEmpty) query = routed.query;
      // The small model sometimes calls a request "help" or "thanks"; if the
      // message actually matches files, answer with them instead.
      if (intent == 'help' || intent == 'thanks') {
        final hits = await engine.search(text);
        if (hits.isNotEmpty) return _searchReply(session, text, hits);
      }
    }

    switch (intent) {
      case 'duplicates':
        _cardsSessionId = session.id;
        await _rescan(
          only: (s) => s.reason.startsWith(core.LocalSortioCore.duplicatePrefix),
        );
        return SortioData.duplicatesReply(suggestions.length);
      case 'template':
        return _setNamingTemplate(_templateIntent.firstMatch(text)![1]!.trim());
      case 'learned':
        return SortioData.habitsReply([
          for (final (key, folder, count) in engine.db.habits().take(8))
            '${key.startsWith('issuer:') ? key.substring(7) : '${key.substring(4)} files'} → $folder ($count×)',
        ]);
      case 'tidy':
        _cardsSessionId = session.id; // this chat's scan owns the cards now
        final scope = folder != null && (_folders[folder]?.allowed ?? false) ? folder : null;
        await _rescan(only: scope == null ? null : (s) => _inFolder(s.sourcePath, scope));
        return SortioData.scanReply(
          suggestions.length,
          scope == null ? visibleFolderNames : [_folders[scope]!.label],
        );
      case 'approve_all':
        return _approveAll();
      case 'ignore_all':
        return _ignoreAll();
      case 'undo':
        return _undoLast();
      case 'explain':
        return _explain(text, query, session, engine);
      case 'help':
        return SortioData.helpReply(visibleFolderNames);
      case 'thanks':
        return SortioData.thanksReply;
    }

    // search
    return _searchReply(session, text, await engine.search(query));
  }

  /// The files the last search in each chat found, so "what is it about?"
  /// knows which file the user means.
  final Map<String, List<String>> _lastFiles = {};

  String _searchReply(ChatSession session, String text, List<core.FileResult> hits) {
    _lastFiles[session.id] = [for (final h in hits) h.path];
    return SortioData.searchReply(text, [
      for (final h in hits)
        (
          name: h.name,
          where: _display(p.dirname(h.path)),
          why: h.matchReason ?? '',
        ),
    ]);
  }

  static final _fileNameIn = RegExp(
    r'[\w\-.()]+\.(?:pdf|jpe?g|png|webp|heic|docx?|xlsx?|pptx?|txt|zip)\b',
    caseSensitive: false,
  );
  static final _listedFile = RegExp(r'^• (.+)\n\s+in (.+?) \(', multiLine: true);
  static final _explainWords = RegExp(
    r"\b(what('?s| is| are)?|about|all|summar(y|ize|ise)|explain|describe|the|this|"
    r"that|it|file|document|contents?|laman|tungkol|saan|ano|ang|ng|sa|buod|"
    r"ibig sabihin|basahin|please|pls|paki)\b|[?!.]",
    caseSensitive: false,
  );

  /// Which files "what is it about?" refers to: a file named in the message,
  /// else the files the chat just found, else a search for the topic.
  Future<List<String>> _filesToExplain(
    String text,
    String query,
    ChatSession session,
    core.LocalSortioCore engine,
  ) async {
    final named = _fileNameIn.firstMatch(text)?[0];
    if (named != null) {
      final found = engine.db.filesNamed(named);
      if (found.isNotEmpty) return [found.first.path];
    }
    var recent = _lastFiles[session.id];
    if (recent == null || recent.isEmpty) {
      // After a restart: read the file list from the chat's last search reply.
      for (final m in session.messages.reversed) {
        if (m.isUser) continue;
        final listed = _listedFile.allMatches(m.text).toList();
        if (listed.isEmpty) continue;
        recent = [
          for (final l in listed)
            p.join(SortioData.storageRoot, l[2]!, l[1]!.trim()),
        ].where((path) => File(path).existsSync()).toList();
        break;
      }
    }
    if (recent != null && recent.isNotEmpty) {
      // "the pdf" -> prefer PDFs; "the photo" -> prefer images.
      final t = text.toLowerCase();
      final wantPdf = t.contains('pdf');
      final wantImage = RegExp(r'\b(photo|picture|image|litrato)\b').hasMatch(t);
      final preferred = recent.where((path) {
        if (wantPdf) return p.extension(path).toLowerCase() == '.pdf';
        if (wantImage) return core.RulesEngine.isImage(path);
        return true;
      }).toList();
      return (preferred.isEmpty ? recent : preferred).take(2).toList();
    }
    // "what is my Meralco bill about?" -> search for the topic.
    final topic = query.replaceAll(_explainWords, ' ').trim();
    if (topic.isEmpty) return const [];
    final hits = await engine.search(topic);
    _lastFiles[session.id] = [for (final h in hits) h.path];
    return [for (final h in hits.take(2)) h.path];
  }

  static const _summaryTimeout = Duration(seconds: 25);
  static final _dates = core.DateExtractor();
  static final _issuers = core.IssuerCleaner();

  /// "What is this PDF about?": reads the file on-device (OCR, cached) and has
  /// the on-device model summarize it. Dates, amounts and sensitive data come
  /// from code, so they are exact.
  Future<String> _explain(
    String text,
    String query,
    ChatSession session,
    core.LocalSortioCore engine,
  ) async {
    final paths = await _filesToExplain(text, query, session, engine);
    if (paths.isEmpty) return SortioData.explainWhichFile;
    final parts = <String>[];
    for (final path in paths) {
      parts.add(await _explainOne(path, engine));
    }
    return parts.join('\n\n');
  }

  Future<String> _explainOne(String path, core.LocalSortioCore engine) async {
    final name = p.basename(path);
    if (!core.RulesEngine.canRead(name)) return SortioData.explainUnreadable(name);

    var content = engine.ocrTextFor(path);
    if (content == null) {
      final ocr = _ocr;
      try {
        content = ocr == null ? '' : await ocr.read(path);
      } on Object catch (e) {
        debugPrint('OCR failed for $path: $e');
        content = '';
      }
      engine.saveOcrText(path, content);
    }
    final clean = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return SortioData.explainNoText(name);

    final insights = core.ContentInsights.fromText(content);
    final found = _dates.extract(content);
    final date = found == null
        ? null
        : '${found.day == null ? '' : '${found.day} '}${_months[found.month - 1]} ${found.year}';

    String? kind;
    String? summary;
    await _modelReady;
    final llm = _llm;
    if (llm != null) {
      try {
        final json = await llm
            .completeJson(
              system: core.summarizeSystemPrompt,
              user: 'File: $name\n\n${clean.length > 1500 ? clean.substring(0, 1500) : clean}',
              schema: core.summarizeSchema,
            )
            .timeout(_summaryTimeout);
        final type = json['doc_type'] as String?;
        final issuer = _issuers.clean(json['issuer'] as String? ?? '');
        if (type != null && type != 'Other') {
          kind = issuer == null || issuer.isEmpty ? 'a $type' : 'a $type from $issuer';
        }
        final s = (json['summary'] as String? ?? '').trim();
        if (s.isNotEmpty) summary = s;
      } on Object catch (e) {
        debugPrint('Summary fell back to an excerpt: $e');
      }
    }
    return SortioData.explainFile(
      name: name,
      kind: kind,
      date: date,
      summary: summary,
      excerpt: clean.length > 160 ? '${clean.substring(0, 160)}…' : clean,
      amount: insights.amountValue == null
          ? null
          : '${insights.amountLabel ?? 'Amount:'} ${insights.amountValue}',
      sensitive: insights.sensitiveBadge,
    );
  }

  /// "approve all": applies every waiting card the AI is sure enough about
  /// (per the strictness setting); the rest stay for the user to check.
  Future<String> _approveAll() async {
    final pending = [
      for (final e in suggestions.entries)
        if (e.value.isPending && !e.value.closing) e.key,
    ];
    if (pending.isEmpty) return SortioData.nothingPending;
    final threshold = strictOutput.threshold;
    var done = 0, unsure = 0, failed = 0;
    for (final id in pending) {
      final planned = _engineById[id];
      final quarantine =
          planned?.category == core.LocalSortioCore.quarantineFolderName;
      if (planned != null &&
          !quarantine &&
          (planned.confidence * 100).round() < threshold) {
        unsure++;
        continue;
      }
      await resolve(id, SuggestionState.applied);
      if (_batchById.containsKey(id)) {
        done++;
      } else {
        failed++;
      }
    }
    return SortioData.approvedAll(done, unsure, failed);
  }

  Future<String> _ignoreAll() async {
    final pending = [
      for (final e in suggestions.entries)
        if (e.value.isPending && !e.value.closing) e.key,
    ];
    for (final id in pending) {
      await resolve(id, SuggestionState.ignored);
    }
    return SortioData.ignoredAll(pending.length);
  }

  /// "undo": reverses the most recent approved card.
  Future<String> _undoLast() async {
    if (_batchById.isEmpty) return SortioData.nothingToUndo;
    final id = _batchById.keys.last;
    final name = suggestions[id]?.fromPath.split('/').last ?? 'The file';
    await undo(id);
    return _batchById.containsKey(id)
        ? 'I could not undo that one. It may have been moved since.'
        : SortioData.undoneLast(name);
  }

  void _finishReply(ChatSession session, String reply) {
    final at = DateTime.now();
    final agentMessage = ChatMessage(
      id: 'a${at.microsecondsSinceEpoch}',
      isUser: false,
      text: reply,
    );
    session
      ..updatedAt = at
      ..messages.add(agentMessage);
    _persistMessage(session, agentMessage);
    typing = false;
    typingSessionId = null;
    _notify();
  }

  /// Opens a conversation from the History (chats) list.
  void openSession(String id) {
    for (final s in chatSessions) {
      if (s.id == id) {
        activeSession = s;
        _notify();
        return;
      }
    }
  }

  /// Deletes a conversation from the History (chats) list. If it was the one
  /// open in the chat screen, the chat falls back to the new-chat welcome state.
  void deleteSession(String id) {
    final index = chatSessions.indexWhere((s) => s.id == id);
    if (index == -1) return;
    chatSessions.removeAt(index);
    // Also drop it from the saved history, or it would come back on restart.
    try {
      _engine?.db.deleteChat(id);
    } on Object catch (e) {
      debugPrint('Could not delete chat $id from the database: $e');
    }
    if (activeSession?.id == id) activeSession = null;
    if (typingSessionId == id) {
      typing = false;
      typingSessionId = null;
    }
    _notify();
  }

  /// Starts a fresh chat: the feed shows a welcome state and the first
  /// message creates a new session in the history.
  void startNewChat() {
    activeSession = null;
    typing = false;
    typingSessionId = null;
    _notify();
  }

  /// Camera button in the composer: take a photo of a document, read it on-device,
  /// and propose where to file it (named by the on-device AI). Like every
  /// suggestion, nothing moves until the user approves.
  Future<void> onAttachTapped() async {
    final engine = _engine;
    final ocr = _ocr;
    if (engine == null || ocr == null) {
      _toast('Scan or upload a file: Sortio reads it on-device. Nothing is uploaded.');
      return;
    }
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    } on Object catch (e) {
      debugPrint('Camera failed: $e');
      _toast(SortioData.cameraUnavailable);
      return;
    }
    if (shot == null || _disposed) return; // user cancelled

    // Keep the photo where photos live (or Downloads if Photos is off).
    final photosOn = _folders['photos']?.allowed ?? false;
    final dir = p.join(SortioData.storageRoot, photosOn ? 'DCIM/Camera' : 'Download');
    await Directory(dir).create(recursive: true);
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'SORTIO_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}.jpg';
    final path = p.join(dir, name);
    await File(shot.path).copy(path);

    // A chat for it: the open one, or a new "Scanned document" chat.
    var session = activeSession;
    if (session == null) {
      session = ChatSession(
        id: 'chat${t.microsecondsSinceEpoch}',
        title: 'Scanned document',
        updatedAt: t,
      );
      chatSessions.insert(0, session);
      activeSession = session;
    }
    final userLine = ChatMessage(
      id: 'u${t.microsecondsSinceEpoch}',
      isUser: true,
      text: SortioData.cameraUserLine,
    );
    session
      ..updatedAt = t
      ..messages.add(userLine);
    _persistMessage(session, userLine);
    typing = true;
    typingSessionId = session.id;
    _notify();

    var text = '';
    try {
      text = await ocr.read(path);
    } on Object catch (e) {
      debugPrint('OCR failed for $path: $e');
    }
    final suggestion = await engine.suggestForDocument(path);
    if (suggestion != null) engine.saveOcrText(path, text);
    final isDocument = suggestion != null && core.RulesEngine.looksLikeDocument(text);

    if (isDocument) {
      // This chat owns the cards now: just the new document.
      _cardsSessionId = session.id;
      ++_scanGeneration;
      suggestions.clear();
      _engineById
        ..clear()
        ..[suggestion.id] = suggestion;
      _insightsById
        ..clear()
        ..[suggestion.id] = core.ContentInsights.fromText(text);
      suggestions[suggestion.id] = _toCard(suggestion);
    }
    final at = DateTime.now();
    final reply = ChatMessage(
      id: 'a${at.microsecondsSinceEpoch}',
      isUser: false,
      text: isDocument ? SortioData.cameraDocument : SortioData.cameraNotDocument,
    );
    session
      ..updatedAt = at
      ..messages.add(reply);
    _persistMessage(session, reply);
    typing = false;
    typingSessionId = null;
    _notify();
    if (isDocument) unawaited(_runAi()); // AI name + amount/badge
  }

  void toggleFolder(String key) {
    final f = _folders[key];
    if (f == null) return;
    _folders = {..._folders, key: f.toggle()};
    _toast(
      f.allowed
          ? 'Sortio can no longer see ${f.label}.'
          : '${f.label} is now visible to Sortio, on-device only.',
    );
    unawaited(_rescan());
  }

  void setStrictness(double value) {
    strictness = value;
    _refreshCards();
    _notify();
  }

  void setRules(String value) {
    rules = value;
    _applyRulesSoon();
    _notify();
  }

  // --- Appearance ------------------------------------------------------------

  /// The Dark mode switch: swaps the palette and repaints the app.
  void setDarkMode(bool value) => _applyTheme(dark: value);

  void _applyTheme({required bool dark}) {
    darkMode = dark;
    SortioThemeBus.instance.setDark(dark);
    _notify();
  }

  /// Two-tap confirm for the memory wipe (arm -> confirm within 3.5 s).
  void onWipeTapped() {
    if (!armed) {
      armed = true;
      _toast('Tap again to confirm. This cannot be undone.');
      _armTimer?.cancel();
      _armTimer = Timer(SortioMotion.armHold, () {
        armed = false;
        _notify();
      });
    } else {
      _armTimer?.cancel();
      armed = false;
      _engine?.wipeMemory();
      _batchById.clear();
      if (_engine != null) {
        chatSessions.clear();
        activeSession = null;
        _cardsSessionId = SortioData.scriptedChatId;
      }
      unawaited(_refreshSavings());
      _toast('AI memory & logs wiped from this device.');
    }
    _notify();
  }

  /// Copies the extracted amount to the clipboard (on-device extraction only).
  void copyExtract() {
    final value =
        suggestions.values
            .firstWhere(
              (s) => (s.extractValue ?? '').isNotEmpty,
              orElse: () => suggestions.values.isEmpty
                  ? SortioData.initialSuggestions().first
                  : suggestions.values.first,
            )
            .extractValue ??
        '';
    if (value.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: value));
    }
    _copyTimer?.cancel();
    copied = true;
    _toast('Copied $value. Extracted on-device, never uploaded.');
    _copyTimer = Timer(SortioMotion.copiedHold, () {
      copied = false;
      _notify();
    });
    _notify();
  }

  // --- Internals ------------------------------------------------------------
  void _toast(String text) {
    _toastTimer?.cancel();
    toastText = text;
    toastOn = true;
    _toastTimer = Timer(SortioMotion.toastHold, () {
      toastOn = false;
      _notify();
    });
    _notify();
  }

  void _later(Duration delay, VoidCallback fn) {
    _timers.add(
      Timer(delay, () {
        _timers.removeWhere((t) => !t.isActive);
        fn();
      }),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    SortioData.liveFiles = null;
    SortioData.liveChats = null;
    _rulesTimer?.cancel();
    _toastTimer?.cancel();
    _armTimer?.cancel();
    _copyTimer?.cancel();
    _replyTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _offlineSub?.cancel();
    _engine?.close();
    _ocr?.close();
    _llm?.dispose();
    super.dispose();
  }
}
