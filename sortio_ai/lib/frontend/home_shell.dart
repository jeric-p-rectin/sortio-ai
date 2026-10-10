// ============================================================================
// Sortio AI — frontend/home_shell.dart
//
// The navigation shell: owns the shared app state (SortioController) and the
// tab state (SortioNavigationController), hosts the five locations inside an
// IndexedStack — so each screen keeps its state when you switch tabs — and
// pins the full-bleed navigation bar to the bottom.
//
// Locations: Home | History | (+) Chat | Files | Settings
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/navigation.dart';
import 'chat_screen.dart';
import 'file_manager_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'nav_bar.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialPanel = StartPanel.none});

  /// Mirrors the prototype's `startPanel` prop: `settings` starts on the
  /// Settings tab instead of Home.
  final StartPanel initialPanel;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final SortioNavigationController _navigation = SortioNavigationController(
    initialTab: widget.initialPanel == StartPanel.settings ? SortioTab.settings : SortioTab.home,
  );

  /// One controller shared by Chat and Settings so folder permissions and the
  /// theme stay in sync everywhere.
  late final SortioController _controller = SortioController();

  @override
  void dispose() {
    _navigation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The theme bus wraps everything (the shell holds the Scaffold) so a Dark
    // mode switch repaints the whole app — including the screens that don't
    // listen to the controller — without losing any state.
    return ListenableBuilder(
      listenable: SortioThemeBus.instance,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: _navigation,
          builder: (context, _) {
            return Scaffold(
              backgroundColor: SortioColors.page,
              body: IndexedStack(
                index: _navigation.tab.index,
                children: [
                  HomeScreen(controller: _controller, navigation: _navigation),
                  HistoryScreen(controller: _controller, navigation: _navigation),
                  ChatScreen(controller: _controller),
                  FileManagerScreen(controller: _controller, navigation: _navigation),
                  SettingsScreen(controller: _controller),
                ],
              ),
              bottomNavigationBar: SortioNavBar(navigation: _navigation),
            );
          },
        );
      },
    );
  }
}
