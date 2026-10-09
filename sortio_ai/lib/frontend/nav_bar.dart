// ============================================================================
// Sortio AI — frontend/nav_bar.dart
//
// The bottom navigation bar: four tabs (Home, History, Files, Settings) with
// a floating "+" button in the centre that opens the chat screen.
//
// Layout contract: the bar is FULL-BLEED — no margins on the left, right or
// bottom. It is glued to the screen's bottom edge and extends behind the
// system gesture area; only the icon row is inset by the safe area.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/design_tokens.dart';
import '../backend/navigation.dart';
import 'shared_widgets.dart';

class SortioNavBar extends StatelessWidget {
  const SortioNavBar({super.key, required this.navigation});

  final SortioNavigationController navigation;

  /// Height of the icon row (above the system gesture inset).
  static const double _barHeight = 62;

  /// How far the floating "+" rises above the bar's top edge.
  static const double _plusOverhang = 18;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = _barHeight + bottomInset + _plusOverhang;

    return ListenableBuilder(
      listenable: navigation,
      builder: (context, _) {
        return SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // -- The bar itself: glued to the bottom, full width ----------
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _bar(context, bottomInset),
              ),

              // -- Floating "+" centred above the bar -----------------------
              Positioned(
                left: 0,
                right: 0,
                bottom: _barHeight + bottomInset - 38,
                child: Center(child: _plusButton(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(BuildContext context, double bottomInset) {
    return Container(
      // No margins: the decoration spans the full width and reaches the very
      // bottom edge of the screen (including the gesture-inset area).
      decoration: const BoxDecoration(
        color: SortioColors.panel,
        border: Border(top: BorderSide(color: SortioColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), offset: Offset(0, -12), blurRadius: 32, spreadRadius: -8),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            _TabItem(
              tab: SortioTab.home,
              icon: Icons.home_outlined,
              label: 'Home',
              navigation: navigation,
            ),
            _TabItem(
              tab: SortioTab.history,
              icon: Icons.history,
              label: 'History',
              navigation: navigation,
            ),
            // Reserved space so the four tabs straddle the floating "+".
            const SizedBox(width: 76),
            _TabItem(
              tab: SortioTab.files,
              icon: Icons.folder_outlined,
              label: 'Files',
              navigation: navigation,
            ),
            _TabItem(
              tab: SortioTab.settings,
              icon: Icons.settings_outlined,
              label: 'Settings',
              navigation: navigation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _plusButton(BuildContext context) {
    final active = navigation.isChatOpen;
    return Semantics(
      button: true,
      label: 'Open Sortio chat',
      child: SortioPressScale(
        onTap: navigation.openChat,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: SortioColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SortioColors.accent.withValues(alpha: active ? 0.9 : 0.7),
                offset: const Offset(0, 8),
                blurRadius: 22,
                spreadRadius: -6,
              ),
              if (active)
                BoxShadow(
                  color: SortioColors.accent.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: const Icon(Icons.add, size: 28, color: SortioColors.onAccent),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.navigation,
  });

  final SortioTab tab;
  final IconData icon;
  final String label;
  final SortioNavigationController navigation;

  @override
  Widget build(BuildContext context) {
    final active = navigation.tab == tab;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          onTap: () => navigation.select(tab),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 34,
              decoration: BoxDecoration(
                color: active ? SortioColors.accent.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? SortioColors.accent.withValues(alpha: 0.35) : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: active ? SortioColors.accentBright : SortioColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
