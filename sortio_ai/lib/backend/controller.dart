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
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'data_output.dart';
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
    _seedChats();
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
  double strictness = 20;
  String rules = '';
  bool armed = false;

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
  SavingsSummary _savings = SortioData.savings;

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
      ..addEntries(SortioData.initialSuggestions().map((s) => MapEntry(s.id, s)));
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
            p.join(SortioData.storageRoot, SortioData.folderDirs[f.key] ?? f.label),
      ];

  /// "/storage/emulated/0/Download/a.pdf" → "Download/a.pdf"
  static String _display(String path) {
    const root = '${SortioData.storageRoot}/';
    return path.startsWith(root) ? path.substring(root.length) : path;
  }

  static String _absolute(String displayPath) =>
      displayPath.startsWith('/') ? displayPath : p.join(SortioData.storageRoot, displayPath);

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
          : [if (renamed) 'Rename', 'Move', if (hasExtract) 'Extract'].join(' · '),
      fromPath: _display(s.sourcePath),
      toPath: _display(s.targetPath),
      tone: quarantine || unsure ? SuggestionTone.amber : SuggestionTone.cyan,
      badge: insights?.sensitiveBadge,
      extractLabel: hasExtract ? insights!.amountLabel : null,
      extractValue: hasExtract ? insights!.amountValue : null,
      reason: quarantine || s.reason.startsWith(SortioData.houseRulePrefix)
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
              for (final m in c.messages) ChatMessage(id: m.id, isUser: m.isUser, text: m.text),
            ],
          ),
      ]);
    if (!chatSessions.any((c) => c.id == SortioData.scriptedChatId)) {
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
    }
    _cardsSessionId = SortioData.scriptedChatId;
    activeSession = chatSessions.firstWhere(
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
      core.StoredMessage(id: m.id, isUser: m.isUser, text: m.text, at: DateTime.now()),
    );
  }

  // --- House rules -----------------------------------------------------------

  static const _rulesKey = 'house_rules';
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
    if (card == null || !card.isPending || card.closing || editingId == s.id) return;
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
    final scans = [
      for (final s in _engineById.values)
        if (s.needsRename || s.aiNamed) s,
    ];
    if (scans.isEmpty) return;
    aiBusy = true;
    _notify();
    try {
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
      await for (final named in engine.aiRename(scans, core.RenameService(llm))) {
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

  Future<void> _rescan() async {
    final engine = _engine;
    if (engine == null) return;
    scanning = true;
    final generation = ++_scanGeneration;
    _notify();
    final found = await engine.scan(_allowedRoots);
    if (_disposed || generation != _scanGeneration) return;
    suggestions.clear();
    _engineById.clear();
    _batchById.clear();
    _insightsById.clear();
    for (final s in found.take(25)) {
      _engineById[s.id] = s;
      suggestions[s.id] = _toCard(s);
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
      if (chat.id != SortioData.scriptedChatId || chat.messages.length < 2) continue;
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];


  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }

  static FileKind _kind(String name) {
    final ext = p.extension(name).toLowerCase();
    if (ext == '.pdf') return FileKind.pdf;
    if (const {'.exe', '.msi', '.bat', '.cmd', '.apk', '.jar', '.scr'}.contains(ext)) {
      return FileKind.exe;
    }
    if (const {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'}.contains(ext)) {
      return FileKind.image;
    }
    return FileKind.doc;
  }

  /// Which File Manager group a path belongs to.
  static String? _folderKeyFor(String path) {
    if (path.contains('/${core.LocalSortioCore.quarantineFolderName}/')) return 'quarantine';
    for (final entry in SortioData.folderDirs.entries) {
      if (p.isWithin(p.join(SortioData.storageRoot, entry.value), path)) return entry.key;
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
    final files = <FileItem>[];
    for (final f in engine.db.recentFiles(limit: 400)) {
      final key = _folderKeyFor(f.path);
      if (key == null) continue;
      final text = f.ocrText;
      files.add(FileItem(
        folderKey: key,
        name: f.name,
        size: _size(f.size),
        modified: '${_months[f.modified.month - 1]} ${f.modified.day}',
        kind: _kind(f.name),
        sensitive: text != null &&
            text.isNotEmpty &&
            core.ContentInsights.fromText(text).isSensitive,
        suggested: pendingSources.contains(f.path),
      ));
    }
    SortioData.liveFiles = files;
    _notify();
  }

  // --- Derived output -------------------------------------------------------
  List<FolderAccess> get folders => _folders.values.toList(growable: false);
  int get allowedFolderCount => _folders.values.where((f) => f.allowed).length;
  String get folderCount => '$allowedFolderCount of 3 allowed';
  List<String> get visibleFolderNames =>
      _folders.values.where((f) => f.allowed).map((f) => f.label).toList(growable: false);

  List<Suggestion> get pendingSuggestions =>
      suggestions.values.where((s) => s.isPending).toList(growable: false);
  bool get allResolved => !scanning && suggestions.values.every((s) => !s.isPending);
  int get appliedCount => suggestions.values.where((s) => s.state == SuggestionState.applied).length;
  String get doneLine => SortioData.doneLine(appliedCount, suggestions.length);

  ({String label, String hint, String mode, int threshold}) get strictOutput =>
      SortioData.strictness(strictness);

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
    if (outcome == SuggestionState.applied && engine != null && planned != null) {
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
    _toast(was == SuggestionState.applied
        ? 'Undone. ${s.fromPath.split('/').last} is back where it was, exactly as it was.'
        : 'Suggestion restored. Nothing has been changed yet.');
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
    final userMessage =
        ChatMessage(id: 'u${sentAt.microsecondsSinceEpoch}', isUser: true, text: text);
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
    } else if (_tidyIntent.hasMatch(text)) {
      _cardsSessionId = session.id; // this chat's scan owns the cards now
      await _rescan();
      reply = SortioData.scanReply(suggestions.length, visibleFolderNames);
    } else {
      final hits = await engine.search(text);
      reply = SortioData.searchReply(text, [
        for (final h in hits)
          (name: h.name, where: _display(p.dirname(h.path)), why: h.matchReason ?? ''),
      ]);
    }
    if (_disposed) return;

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

  /// Starts a fresh chat: the feed shows a welcome state and the first
  /// message creates a new session in the history.
  void startNewChat() {
    activeSession = null;
    typing = false;
    typingSessionId = null;
    _notify();
  }

  void onAttachTapped() =>
      _toast('Scan or upload a file: Sortio reads it on-device. Nothing is uploaded.');

  void toggleFolder(String key) {
    final f = _folders[key];
    if (f == null) return;
    _folders = {..._folders, key: f.toggle()};
    _toast(f.allowed
        ? 'Sortio can no longer see ${f.label}.'
        : '${f.label} is now visible to Sortio, on-device only.');
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
      rules = '';
      _engine?.wipeMemory();
      _engine?.db.saveSetting(_rulesKey, '');
      _engine?.houseRules = core.HouseRules.empty;
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
    final value = suggestions.values
            .firstWhere((s) => (s.extractValue ?? '').isNotEmpty,
                orElse: () => suggestions.values.isEmpty
                    ? SortioData.initialSuggestions().first
                    : suggestions.values.first)
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
    _timers.add(Timer(delay, () {
      _timers.removeWhere((t) => !t.isActive);
      fn();
    }));
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
