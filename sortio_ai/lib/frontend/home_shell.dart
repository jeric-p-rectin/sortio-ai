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

import 'package:flutter/foundation.dart';
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
  late final SortioNavigationController _navigation =
      SortioNavigationController(
        initialTab: widget.initialPanel == StartPanel.settings
            ? SortioTab.settings
            : SortioTab.home,
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
            final desktop = MediaQuery.sizeOf(context).width >= 900;
            final screens = IndexedStack(
              index: _navigation.tab.index,
              children: [
                HomeScreen(controller: _controller, navigation: _navigation),
                HistoryScreen(controller: _controller, navigation: _navigation),
                ChatScreen(controller: _controller),
                FileManagerScreen(
                  controller: _controller,
                  navigation: _navigation,
                ),
                SettingsScreen(controller: _controller),
              ],
            );
            return Scaffold(
              backgroundColor: SortioColors.page,
              body: desktop
                  ? SafeArea(
                      child: Row(
                        children: [
                          _DesktopSidebar(
                            navigation: _navigation,
                            controller: _controller,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                if (kIsWeb) const _BrowserPreviewBanner(),
                                Expanded(
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 1160,
                                      ),
                                      child: screens,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (kIsWeb) const _BrowserPreviewBanner(),
                        Expanded(child: screens),
                      ],
                    ),
              bottomNavigationBar: desktop
                  ? null
                  : SortioNavBar(navigation: _navigation),
            );
          },
        );
      },
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({required this.navigation, required this.controller});

  final SortioNavigationController navigation;
  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: SortioColors.panel,
        border: Border(right: BorderSide(color: SortioColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  'assets/images/sortio_logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sortio AI',
                    style: TextStyle(
                      color: SortioColors.textBright,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Your files, tidy',
                    style: TextStyle(
                      color: SortioColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          _SidebarAction(
            icon: Icons.add,
            label: 'New chat',
            selected: navigation.isChatOpen,
            primary: true,
            onTap: () {
              controller.startNewChat();
              navigation.openChat();
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 0, 9),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: SortioColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          _SidebarAction(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: navigation.tab == SortioTab.home,
            onTap: navigation.openHome,
          ),
          _SidebarAction(
            icon: Icons.history,
            label: 'History',
            selected: navigation.tab == SortioTab.history,
            onTap: navigation.openHistory,
          ),
          _SidebarAction(
            icon: Icons.folder_outlined,
            label: 'Files',
            selected: navigation.tab == SortioTab.files,
            onTap: navigation.openFiles,
          ),
          _SidebarAction(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: navigation.tab == SortioTab.settings,
            onTap: navigation.openSettings,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SortioColors.borderCard),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 17,
                  color: SortioColors.greenBright,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kIsWeb ? 'Sample preview' : 'Private by design',
                        style: TextStyle(
                          color: SortioColors.textBody,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        kIsWeb
                            ? 'No personal files are accessed.'
                            : 'Your files stay on this device.',
                        style: TextStyle(
                          color: SortioColors.textMuted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? SortioColors.onAccent : SortioColors.textBody;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: primary
            ? SortioColors.accent
            : selected
            ? SortioColors.hover
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected && !primary
                    ? SortioColors.borderCard
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: primary ? foreground : SortioColors.accentBright,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    color: primary ? foreground : SortioColors.textBody,
                    fontSize: 13,
                    fontWeight: selected || primary
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowserPreviewBanner extends StatelessWidget {
  const _BrowserPreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: SortioColors.accent.withValues(alpha: 0.09),
        border: Border(bottom: BorderSide(color: SortioColors.borderCard)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 15, color: SortioColors.accentBright),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Browser preview · sample files only. It cannot access or change files on your device.',
              style: TextStyle(color: SortioColors.textSoft, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
