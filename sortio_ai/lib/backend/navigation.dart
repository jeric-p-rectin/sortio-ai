// ============================================================================
// Sortio AI — backend/navigation.dart
//
// Bottom navigation model: four tabs (Home, History, Files, Settings) plus the
// floating "+" action in the middle of the bar, which opens the chat screen.
// ============================================================================

import 'package:flutter/material.dart';

/// The five locations of the app. [SortioTab.chat] is reached through the
/// floating "+" button in the centre of the navigation bar, not a tab icon.
enum SortioTab { home, history, chat, files, settings }

class SortioNavigationController extends ChangeNotifier {
  SortioNavigationController({SortioTab initialTab = SortioTab.chat}) : _tab = initialTab;

  SortioTab _tab;
  SortioTab get tab => _tab;

  bool get isChatOpen => _tab == SortioTab.chat;

  void select(SortioTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  void openChat() => select(SortioTab.chat);
  void openHome() => select(SortioTab.home);
  void openHistory() => select(SortioTab.history);
  void openFiles() => select(SortioTab.files);
  void openSettings() => select(SortioTab.settings);
}
