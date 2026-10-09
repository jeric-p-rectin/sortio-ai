// ============================================================================
// Sortio AI — backend/controller.dart
//
// SortioController — ALL app state & behaviour (the on-device agent logic):
// offline mode, suggestion approve/edit/ignore/undo, folder permissions,
// strictness, house rules, session switching, chat, toasts and the two-tap
// memory wipe. Screens listen to this ChangeNotifier and rebuild.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_output.dart';
import 'models.dart';
import 'motion.dart';

/// Which overlay is open when the app starts (mirrors the prototype's
/// `startPanel` prop: none | drawer | settings).
enum StartPanel { none, drawer, settings }

class SortioController extends ChangeNotifier {
  SortioController({StartPanel initialPanel = StartPanel.none})
      : drawerOpen = initialPanel == StartPanel.drawer,
        sheetOpen = initialPanel == StartPanel.settings;

  // --- Core state -----------------------------------------------------------
  bool offline = false;
  bool drawerOpen;
  bool sheetOpen;

  String toastText = '';
  bool toastOn = false;

  /// id -> suggestion (insertion-ordered: bill first, exe second).
  late final Map<String, Suggestion> suggestions = {
    for (final s in SortioData.initialSuggestions()) s.id: s,
  };

  String? editingId;
  String draft = '';
  bool copied = false;

  Map<String, FolderAccess> _folders = {
    for (final f in SortioData.folders()) f.key: f,
  };
  double strictness = 20;
  String rules = '';
  bool armed = false;
  String activeSession = 'now';

  final List<ChatMessage> extraMessages = <ChatMessage>[];
  bool typing = false;
  String composerText = '';

  Timer? _toastTimer;
  Timer? _armTimer;
  Timer? _copyTimer;
  Timer? _replyTimer;
  final List<Timer> _timers = <Timer>[];

  // --- Derived output -------------------------------------------------------
  List<FolderAccess> get folders => _folders.values.toList(growable: false);
  int get allowedFolderCount => _folders.values.where((f) => f.allowed).length;
  String get folderCount => '$allowedFolderCount of 3 allowed';
  List<String> get visibleFolderNames =>
      _folders.values.where((f) => f.allowed).map((f) => f.label).toList(growable: false);

  List<Suggestion> get pendingSuggestions =>
      suggestions.values.where((s) => s.isPending).toList(growable: false);
  bool get allResolved => suggestions.values.every((s) => !s.isPending);
  int get appliedCount => suggestions.values.where((s) => s.state == SuggestionState.applied).length;
  String get doneLine => SortioData.doneLine(appliedCount);

  String get modelLine => offline ? SortioData.offlineModelLine : SortioData.onlineModelLine;
  String get footLine => offline ? SortioData.offlineFootLine : SortioData.onlineFootLine;

  ({String label, String hint, String mode, int threshold}) get strictOutput =>
      SortioData.strictness(strictness);

  List<SessionEntry> get sessions => SortioData.sessions();
  SavingsSummary get savings => SortioData.savings;

  // --- Actions --------------------------------------------------------------
  void toggleNetwork() {
    offline = !offline;
    _toast(offline
        ? 'Network disconnected. AI is 100% operational locally.'
        : 'Network back on. Sortio still never uploads your files.');
  }

  void openDrawer() {
    drawerOpen = true;
    sheetOpen = false;
    _notify();
  }

  void openSheet() {
    sheetOpen = true;
    drawerOpen = false;
    _notify();
  }

  void closePanels() {
    drawerOpen = false;
    sheetOpen = false;
    armed = false;
    _armTimer?.cancel();
    _notify();
  }

  /// Approve or ignore a suggestion: collapse the card first (380 ms), then
  /// swap in the applied/ignored row — same sequencing as the prototype.
  void resolve(String id, SuggestionState outcome) {
    final s = suggestions[id];
    if (s == null || s.closing || !s.isPending) return;
    s.closing = true;
    _notify();
    _later(SortioMotion.resolveDelay, () {
      s
        ..closing = false
        ..state = outcome;
      _notify();
    });
  }

  void undo(String id) {
    final s = suggestions[id];
    if (s == null) return;
    final was = s.state;
    s.state = SuggestionState.pending;
    _toast(was == SuggestionState.applied
        ? 'Undone. ${s.fromPath.split('/').last} is back in Downloads, exactly as it was.'
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
      suggestions[id]!.toPath = v;
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

  void sendMessage() {
    final text = composerText.trim();
    if (text.isEmpty) {
      _toast(SortioData.emptyMessageHint);
      return;
    }
    extraMessages.add(ChatMessage(id: 'u${DateTime.now().microsecondsSinceEpoch}', isUser: true, text: text));
    composerText = '';
    typing = true;
    _notify();
    _later(SortioMotion.agentThinking, () {
      typing = false;
      extraMessages.add(ChatMessage(
        id: 'a${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        text: SortioData.agentReply(visibleFolderNames),
      ));
      _notify();
    });
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
  }

  void setStrictness(double value) {
    strictness = value;
    _notify();
  }

  void setRules(String value) {
    rules = value;
    _notify();
  }

  void pickSession(String id) {
    activeSession = id;
    if (id == 'now') drawerOpen = false;
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
      _toast('AI memory & logs wiped from this device.');
    }
    _notify();
  }

  /// Copies the extracted amount to the clipboard (on-device extraction only).
  void copyExtract() {
    final value = suggestions['bill']?.extractValue ?? '';
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

  void _notify() => notifyListeners();

  @override
  void dispose() {
    _toastTimer?.cancel();
    _armTimer?.cancel();
    _copyTimer?.cancel();
    _replyTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}
