// ============================================================================
// Sortio AI — frontend/nav_bar.dart
//
// The bottom navigation bar: four tabs (Home, History, Files, Settings) with
// a floating "+" button in the centre that opens the chat screen.
//
// The indicator dot floats on the bar's top edge, cradled by a smooth round
// notch carved into the bar (the dot never touches the bar or the icons). It
// glides to the selected tab, and only that tab shows its label.
//
// The "+" is a station of its own: going to chat, the dot first glides to the
// middle (tucking behind the button) and only then does the "+" grow. Leaving
// chat, the dot swipes out from the middle to the chosen tab.
//
// Layout contract: the bar is FULL-BLEED — no margins on the left, right or
// bottom. It is glued to the screen's bottom edge and extends behind the
// system gesture area; only the icon row is inset by the safe area.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/design_tokens.dart';
import '../backend/navigation.dart';
import 'shared_widgets.dart';

class SortioNavBar extends StatefulWidget {
  const SortioNavBar({super.key, required this.navigation});

  final SortioNavigationController navigation;

  /// Height of the icon row (above the system gesture inset).
  static const double _barHeight = 68;

  /// How far the floating "+" rises above the bar's top edge.
  static const double _plusOverhang = 18;

  /// Width reserved in the middle of the bar for the floating "+".
  static const double _plusGap = 76;

  /// Gap from the bar's top edge to the icons — keeps the dot and its notch
  /// clear of them.
  static const double _iconTop = 25;

  /// Diameter of the indicator dot.
  static const double _dotSize = 8;

  /// Clear space kept between the dot and the walls of the notch.
  static const double _dotGap = 4;

  /// How long the dot + notch take to glide to another station.
  static const Duration _slide = Duration(milliseconds: 460);
  static const Curve _slideCurve = Curves.easeInOutCubicEmphasized;

  /// How much the "+" grows while chat is the current screen.
  static const double _plusActiveScale = 1.2;

  @override
  State<SortioNavBar> createState() => _SortioNavBarState();
}

class _SortioNavBarState extends State<SortioNavBar> {
  /// True once the "+" should be enlarged. When chat opens it is switched on
  /// only after the dot has arrived in the middle; leaving chat clears it at
  /// once.
  late bool _plusGrown = widget.navigation.isChatOpen;
  Timer? _growTimer;

  static int? _slotOf(SortioTab tab) => switch (tab) {
        SortioTab.home => 0,
        SortioTab.history => 1,
        SortioTab.files => 2,
        SortioTab.settings => 3,
        SortioTab.chat => null,
      };

  SortioNavigationController get navigation => widget.navigation;

  @override
  void initState() {
    super.initState();
    navigation.addListener(_onNavigation);
  }

  @override
  void didUpdateWidget(SortioNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigation != widget.navigation) {
      oldWidget.navigation.removeListener(_onNavigation);
      widget.navigation.addListener(_onNavigation);
    }
  }

  @override
  void dispose() {
    _growTimer?.cancel();
    navigation.removeListener(_onNavigation);
    super.dispose();
  }

  void _onNavigation() {
    _growTimer?.cancel();
    if (navigation.isChatOpen) {
      // Let the dot reach the middle first, then grow the button.
      _growTimer = Timer(SortioNavBar._slide, () {
        if (!mounted || !navigation.isChatOpen) return;
        setState(() => _plusGrown = true);
      });
    } else if (_plusGrown) {
      setState(() => _plusGrown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight =
        SortioNavBar._barHeight + bottomInset + SortioNavBar._plusOverhang;

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

              // -- Floating "+" centred above the bar (drawn over the dot) --
              Positioned(
                left: 0,
                right: 0,
                bottom: SortioNavBar._barHeight + bottomInset - 38,
                child: Center(child: _plusButton(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(BuildContext context, double bottomInset) {
    final slot = _slotOf(navigation.tab);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tabWidth = (width - SortioNavBar._plusGap) / 4;
        // Centre of each of the four tab slots (the "+" gap sits between
        // slots 1 and 2).
        double centerOf(int s) =>
            tabWidth * s + (s >= 2 ? SortioNavBar._plusGap : 0) + tabWidth / 2;

        // Chat has no tab icon: its station is the middle of the bar, where
        // the dot tucks in behind the "+".
        final targetX = slot == null ? width / 2 : centerOf(slot);

        // Re-targeting mid-flight continues from the current position, so
        // quick taps between stations stay smooth.
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: targetX),
          duration: SortioNavBar._slide,
          curve: SortioNavBar._slideCurve,
          builder: (context, notchX, _) {
            return CustomPaint(
              painter: _NavBarPainter(
                notchX: notchX,
                dotSize: SortioNavBar._dotSize,
                dotGap: SortioNavBar._dotGap,
                fill: SortioColors.panel,
                border: SortioColors.border,
                shadow: SortioColors.isDark
                    ? const Color(0x66000000)
                    : const Color(0x1A0F172A),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  height: SortioNavBar._barHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
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
                          // Reserved space so the four tabs straddle the
                          // floating "+".
                          const SizedBox(width: SortioNavBar._plusGap),
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

                      // -- The dot, floating inside its notch -----------------
                      Positioned(
                        left: notchX - SortioNavBar._dotSize / 2,
                        top: _NavBarPainter.dotTop(
                          dotSize: SortioNavBar._dotSize,
                          dotGap: SortioNavBar._dotGap,
                        ),
                        child: IgnorePointer(
                          child: Container(
                            width: SortioNavBar._dotSize,
                            height: SortioNavBar._dotSize,
                            decoration: BoxDecoration(
                              color: SortioColors.accentBright,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: SortioColors.accent.withValues(alpha: 0.7),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _plusButton(BuildContext context) {
    final grown = _plusGrown;
    return Semantics(
      button: true,
      selected: navigation.isChatOpen,
      label: 'Open Sortio chat',
      child: SortioPressScale(
        onTap: navigation.openChat,
        // Current screen: the "+" grows once the dot has arrived behind it.
        child: AnimatedScale(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          scale: grown ? SortioNavBar._plusActiveScale : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SortioColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SortioColors.accent.withValues(alpha: grown ? 0.9 : 0.7),
                  offset: const Offset(0, 8),
                  blurRadius: 22,
                  spreadRadius: -6,
                ),
                if (grown)
                  BoxShadow(
                    color: SortioColors.accent.withValues(alpha: 0.25),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: Icon(Icons.add, size: 28, color: SortioColors.onAccent),
          ),
        ),
      ),
    );
  }
}

/// Paints the bar body (shadow, fill, top border) with a smooth round notch
/// carved out of its top edge at [notchX].
class _NavBarPainter extends CustomPainter {
  _NavBarPainter({
    required this.notchX,
    required this.dotSize,
    required this.dotGap,
    required this.fill,
    required this.border,
    required this.shadow,
  });

  final double notchX;
  final double dotSize;
  final double dotGap;
  final Color fill;
  final Color border;
  final Color shadow;

  /// Half-width of the notch's mouth and of its widest point.
  static const double _mouth = 24;
  static const double _belly = 13.5;

  /// How far the dot sits above the centre of the notch's gap — a hair up so
  /// there is more air beneath it.
  static const double _lift = 1.5;

  /// Notch depth for a dot of [dotSize] with [dotGap] clear around it.
  static double depthFor(double dotSize, double dotGap) => dotSize + dotGap * 2 + 2;

  /// Top offset of the dot so it floats inside the notch, clear of its walls.
  static double dotTop({required double dotSize, required double dotGap}) =>
      depthFor(dotSize, dotGap) - dotGap - dotSize - _lift;

  Path _contour(Size size) {
    final depth = depthFor(dotSize, dotGap);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(notchX - _mouth, 0)
      ..cubicTo(notchX - _belly, 0, notchX - _belly, depth, notchX, depth)
      ..cubicTo(notchX + _belly, depth, notchX + _belly, 0, notchX + _mouth, 0)
      ..lineTo(size.width, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final contour = _contour(size);
    final body = Path.from(contour)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      body.shift(const Offset(0, -12)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(body, Paint()..color = fill);
    canvas.drawPath(
      contour,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_NavBarPainter old) =>
      old.notchX != notchX ||
      old.fill != fill ||
      old.border != border ||
      old.shadow != shadow;
}

/// One tab: just the icon, with its label fading in underneath while it is the
/// current screen. No box — the dot above marks the selection.
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
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: SortioNavBar._iconTop),
            child: Column(
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: active ? SortioColors.accentBright : SortioColors.textMuted,
                  ),
                  duration: const Duration(milliseconds: 320),
                  builder: (context, color, _) => Icon(icon, size: 22, color: color),
                ),
                // Fixed-height slot so the icon never jumps; the label only
                // exists (and fades in) for the current tab.
                SizedBox(
                  height: 16,
                  child: active
                      ? TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOut,
                          builder: (context, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(offset: Offset(0, (1 - t) * 3), child: child),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: SortioColors.accentBright,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
