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
import 'models.dart';
import 'motion.dart';
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
      ..addAll(SortioData.chatSessions());
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
  bool get isScriptedChat => activeSession?.id == SortioData.scriptedChatId;

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
      _offlineSub = _engine!.isOffline.listen(_onRealOffline);
      await _rescan();
      await _refreshSavings();
    } on Object catch (e) {
      debugPrint('Sortio engine unavailable, using demo data: $e');
      _loadDemo();
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
    return Suggestion(
      id: s.id,
      kind: quarantine
          ? 'Quarantine'
          : renamed
              ? 'Rename · Move'
              : 'Move',
      fromPath: _display(s.sourcePath),
      toPath: _display(s.targetPath),
      tone: quarantine ? SuggestionTone.amber : SuggestionTone.cyan,
      reason: quarantine ? s.reason : null,
    );
  }

  Future<void> _rescan() async {
    final engine = _engine;
    if (engine == null) return;
    scanning = true;
    _notify();
    final found = await engine.scan(_allowedRoots);
    if (_disposed) return;
    suggestions.clear();
    _engineById.clear();
    _batchById.clear();
    for (final s in found.take(25)) {
      _engineById[s.id] = s;
      suggestions[s.id] = _toCard(s);
    }
    scanning = false;
    _notify();
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
    session
      ..updatedAt = sentAt
      ..messages.add(ChatMessage(id: 'u${sentAt.microsecondsSinceEpoch}', isUser: true, text: text));
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
    session
      ..updatedAt = at
      ..messages.add(ChatMessage(
        id: 'a${at.microsecondsSinceEpoch}',
        isUser: false,
        text: reply,
      ));
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
    _notify();
  }

  void setRules(String value) {
    rules = value;
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
      _batchById.clear();
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
    _toastTimer?.cancel();
    _armTimer?.cancel();
    _copyTimer?.cancel();
    _replyTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _offlineSub?.cancel();
    _engine?.close();
    super.dispose();
  }
}
