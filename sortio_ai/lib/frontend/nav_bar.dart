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
// The "+" is a station of its own: going to chat, the dot glides to the middle
// and tucks behind the button. The "+" grows in lock-step with the dot — its
// size is driven by the dot's distance, not by a separate timer — so growth
// begins as the dot reaches the button's perimeter and there is no delay.
// Leaving chat, the "+" relaxes at once and the dot swipes out from the middle.
//
// The "+" also has a soft blue fog around it that slowly drifts and breathes.
//
// Layout contract: the bar is FULL-BLEED — no margins on the left, right or
// bottom. It is glued to the screen's bottom edge and extends behind the
// system gesture area; only the icon row is inset by the safe area.
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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

  /// The "+" grows with the dot, driven by the dot's distance from the bar's
  /// centre. Growth starts as the dot reaches the button's perimeter (button
  /// radius 28 + dot radius 4, plus a hair of lead) and is complete once the
  /// dot is tucked behind the button.
  static const double _growStart = 36;
  static const double _growEnd = 14;

  /// How quickly the "+" relaxes once chat is left.
  static const Duration _relaxDuration = Duration(milliseconds: 240);

  /// One full loop of the "+" fog (the blobs drift once around per loop).
  static const Duration _glowCycle = Duration(seconds: 7);

  @override
  State<SortioNavBar> createState() => _SortioNavBarState();
}

class _SortioNavBarState extends State<SortioNavBar> with TickerProviderStateMixin {
  /// Drives the dot's glide between stations (0 → 1).
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: SortioNavBar._slide,
  );

  /// Drives the "+" fog: a seamless 0 → 1 loop, forever.
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: SortioNavBar._glowCycle,
  )..repeat();

  /// Relaxes the "+" back to normal size after chat is left (value 1 → 0).
  late final AnimationController _relax = AnimationController(
    vsync: this,
    duration: SortioNavBar._relaxDuration,
  );

  bool _wasChat = false;

  /// Last known bar width, and the glide's start/end x.
  double? _width;
  double _xFrom = 0;
  double _xTo = 0;

  static int? _slotOf(SortioTab tab) => switch (tab) {
        SortioTab.home => 0,
        SortioTab.history => 1,
        SortioTab.files => 2,
        SortioTab.settings => 3,
        SortioTab.chat => null,
      };

  SortioNavigationController get navigation => widget.navigation;

  /// Centre x of a tab slot (the "+" gap sits between slots 1 and 2). Chat has
  /// no tab icon: its station is the middle of the bar, behind the "+".
  static double _stationX(double width, SortioTab tab) {
    final slot = _slotOf(tab);
    if (slot == null) return width / 2;
    final tabWidth = (width - SortioNavBar._plusGap) / 4;
    return tabWidth * slot + (slot >= 2 ? SortioNavBar._plusGap : 0) + tabWidth / 2;
  }

  /// Where the dot is right now.
  double get _x =>
      _xFrom + (_xTo - _xFrom) * SortioNavBar._slideCurve.transform(_slide.value);

  /// 0 → 1 from the dot's distance to the bar's centre: 0 while it is outside
  /// the button's perimeter, 1 once it is tucked behind the button.
  double _proximity(double x, double width) {
    final raw = (SortioNavBar._growStart - (x - width / 2).abs()) /
        (SortioNavBar._growStart - SortioNavBar._growEnd);
    return Curves.easeInOut.transform(raw.clamp(0.0, 1.0).toDouble());
  }

  /// How grown the "+" is right now (0 = normal, 1 = fully grown).
  double _grown(double x, double width) => math.max(
        navigation.isChatOpen ? _proximity(x, width) : 0.0,
        _relax.value,
      );

  @override
  void initState() {
    super.initState();
    _wasChat = navigation.isChatOpen;
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
    navigation.removeListener(_onNavigation);
    _slide.dispose();
    _glow.dispose();
    _relax.dispose();
    super.dispose();
  }

  void _onNavigation() {
    final width = _width;
    if (width == null) return;

    // Leaving chat: the "+" relaxes at once, from however grown it is now.
    final chat = navigation.isChatOpen;
    if (_wasChat && !chat) {
      _relax.value = math.max(_relax.value, _proximity(_x, width));
      _relax.animateTo(0, curve: Curves.easeOutCubic);
    }
    _wasChat = chat;

    final to = _stationX(width, navigation.tab);
    if (to == _xTo) return;
    // Re-targeting mid-flight continues from the dot's current position, so
    // quick taps between stations stay smooth.
    _xFrom = _x;
    _xTo = to;
    _slide.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight =
        SortioNavBar._barHeight + bottomInset + SortioNavBar._plusOverhang;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (_width != width) {
          // First layout (or a width change): put the dot on its station
          // without animating.
          _width = width;
          _xFrom = _xTo = _stationX(width, navigation.tab);
        }

        return ListenableBuilder(
          listenable: navigation,
          builder: (context, _) {
            return AnimatedBuilder(
              animation: Listenable.merge([_slide, _relax]),
              builder: (context, _) {
                final x = _x;
                // The "+" grows in lock-step with the dot (no separate timer,
                // so no delay) and relaxes the instant chat closes.
                final grown = _grown(x, width);

                return SizedBox(
                  height: totalHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // -- The bar itself: glued to the bottom, full width ----
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _bar(context, bottomInset, x),
                      ),

                      // -- Floating "+" centred above the bar (over the dot) --
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: SortioNavBar._barHeight + bottomInset - 38,
                        child: Center(child: _plusButton(context, grown)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _bar(BuildContext context, double bottomInset, double notchX) {
    return CustomPaint(
      painter: _NavBarPainter(
        notchX: notchX,
        dotSize: SortioNavBar._dotSize,
        dotGap: SortioNavBar._dotGap,
        fill: SortioColors.panel,
        border: SortioColors.border,
        shadow: SortioColors.isDark ? const Color(0x66000000) : const Color(0x1A0F172A),
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
                  // Reserved space so the four tabs straddle the floating "+".
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

              // -- The dot, floating inside its notch ---------------------------
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
  }

  Widget _plusButton(BuildContext context, double grown) {
    // Eased growth, locked to the dot's position (see _grown).
    final scale = 1 + (SortioNavBar._plusActiveScale - 1) * grown;

    return Semantics(
      button: true,
      selected: navigation.isChatOpen,
      label: 'Open Sortio chat',
      child: SortioPressScale(
        onTap: navigation.openChat,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // The soft blue fog: blobs drifting slowly around the button.
                // Own repaint boundary + own ticker, so the animation never
                // rebuilds the rest of the bar.
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _glow,
                        builder: (context, _) => CustomPaint(
                          painter: _FogPainter(
                            t: _glow.value,
                            base: SortioColors.accent,
                            light: SortioColors.accentBright,
                            boost: grown,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: SortioColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Crisp halo ring that appears with the growth.
                      if (grown > 0.001)
                        BoxShadow(
                          color: SortioColors.accent.withValues(alpha: 0.25 * grown),
                          blurRadius: 0,
                          spreadRadius: 4 * grown,
                        ),
                    ],
                  ),
                  child: Icon(Icons.add, size: 28, color: SortioColors.onAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the "+" button's blue fog: a breathing base glow under the button
/// plus two soft blobs drifting slowly around it.
///
/// [t] is a seamless 0 → 1 loop. Every motion uses a whole number of turns per
/// loop, so nothing jumps or stalls when the loop restarts. [boost] (0 → 1)
/// brightens the fog while the button is grown.
class _FogPainter extends CustomPainter {
  _FogPainter({
    required this.t,
    required this.base,
    required this.light,
    required this.boost,
  });

  final double t;
  final Color base;
  final Color light;
  final double boost;

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // 0 → 1 → 0, twice per loop, perfectly smooth.
    final breath = 0.5 - 0.5 * math.cos(_tau * 2 * t);

    // Base glow, swelling and fading under the button.
    canvas.drawCircle(
      c + const Offset(0, 8),
      28 + lerpDouble(-7, -3, breath)!,
      Paint()
        ..color = base.withValues(
          alpha: (lerpDouble(0.45, 0.8, breath)! + 0.12 * boost).clamp(0.0, 1.0).toDouble(),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lerpDouble(9, 16, breath)!),
    );

    // Blob one: drifts clockwise.
    final a1 = _tau * t;
    canvas.drawCircle(
      c + Offset(math.cos(a1) * 15, math.sin(a1) * 11 + 6),
      16 + 3 * math.sin(_tau * 3 * t),
      Paint()
        ..color = base.withValues(alpha: 0.42 + 0.12 * boost)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );

    // Blob two: lighter, drifts the other way round, a little wider.
    final a2 = -_tau * t + 2.2;
    canvas.drawCircle(
      c + Offset(math.cos(a2) * 19, math.sin(a2) * 9 + 9),
      14 + 3 * math.sin(_tau * 2 * t + 1.3),
      Paint()
        ..color = light.withValues(alpha: 0.30 + 0.10 * boost)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  @override
  bool shouldRepaint(_FogPainter old) =>
      old.t != t || old.base != base || old.light != light || old.boost != boost;
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
