// ============================================================================
// Sortio AI — backend/animations.dart
//
// Every animation in the app, as reusable primitives the screens compose:
//   • PopIn            — the CSS `pop` entrance (bubbles, cards, rows)
//   • TypingDots       — the CSS `blink` typing indicator
//   • PulseBox         — the CSS `pulse` glow (armed "wipe" button)
//   • SortioSwitch     — the animated pill/track switches
//   • CollapseOut      — the card height-collapse transition
//   • FadeThroughRoute — the page transition used by the router
// ============================================================================

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'motion.dart';

/// Entrance animation matching the CSS `@keyframes pop`:
/// from { opacity: 0; translateY(8px) scale(.98) } to { none }.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = SortioMotion.pop,
    this.curve = SortioMotion.slideIn,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: widget.curve);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(anim),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Three blinking dots — mirrors the CSS `@keyframes blink` with the staggered
/// delays (0 / .18s / .36s of a 1.1s cycle).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color});

  /// Defaults to the muted text color of the active theme.
  final Color? color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: SortioMotion.typingCycle)..repeat();

  static const List<double> _delays = [0, 0.18 / 1.1, 0.36 / 1.1];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// CSS blink: 0%/80%/100% -> .25 opacity, 40% -> 1.
  double _blink(double t) {
    t = t.clamp(0.0, 1.0);
    return t < 0.4 ? 0.25 + 0.75 * (t / 0.4) : 1 - 0.75 * ((t - 0.4) / 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: _blink((_controller.value - _delays[i]) % 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.color ?? SortioColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pulsing glow ring for the armed "Wipe AI Memory & Logs" button — mirrors
/// the CSS `@keyframes pulse` (box-shadow 0 -> 6px -> 0 while armed).
class PulseBox extends StatefulWidget {
  const PulseBox({super.key, required this.child, required this.active, this.color});

  final Widget child;
  final bool active;

  /// Defaults to the danger color of the active theme.
  final Color? color;

  @override
  State<PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<PulseBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: SortioMotion.pulse);

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulseBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final spread = 6.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        final alpha = 0.5 * (t < 0.5 ? 1 - t * 2 : (t - 0.5) * 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: (widget.color ?? SortioColors.redArm).withValues(alpha: alpha),
                      blurRadius: 0,
                      spreadRadius: spread,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Pill switch matching the prototype's `.sw` / `.net .trk` toggles:
/// 56x44 hit area, 52x32 track, 24px thumb sliding 20px (scaled variants used
/// by the header "Offline Mode" pill).
class SortioSwitch extends StatelessWidget {
  const SortioSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 56,
    this.height = 44,
    this.trackWidth = 52,
    this.trackHeight = 32,
    this.thumbSize = 24,
    this.travel = 20,
    this.trackOff,
    this.trackOn,
    this.thumbOff,
    this.thumbOn = Colors.white,
    this.duration = const Duration(milliseconds: 280),
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final double trackWidth;
  final double trackHeight;
  final double thumbSize;
  final double travel;

  /// Track/thumb colors — defaulting to the active theme's palette.
  final Color? trackOff;
  final Color? trackOn;
  final Color? thumbOff;
  final Color? thumbOn;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final offTrack = trackOff ?? SortioColors.borderStrong;
    final onTrack = trackOn ?? SortioColors.accent;
    final offThumb = thumbOff ?? SortioColors.textSoft;
    final onThumb = thumbOn ?? Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedContainer(
            duration: duration,
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(
              color: value ? onTrack : offTrack,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: duration,
              curve: SortioMotion.slideIn,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: duration,
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: value ? onThumb : offThumb,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Height-collapse wrapper mirroring the prototype's `.card.collapsing`
/// transition (max-height/opacity/scale over 400 ms, easeInOut).
class CollapseOut extends StatefulWidget {
  const CollapseOut({super.key, required this.collapsed, required this.child});

  final bool collapsed;
  final Widget child;

  @override
  State<CollapseOut> createState() => _CollapseOutState();
}

class _CollapseOutState extends State<CollapseOut> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: SortioMotion.collapse)
        ..value = widget.collapsed ? 1 : 0;

  @override
  void didUpdateWidget(CollapseOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed) {
      widget.collapsed ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: SortioMotion.collapseCurve),
      ),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.7, curve: Curves.easeOut),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Page transition used by the router — a quick fade-through, consistent with
/// the prototype's overlay feel.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 240),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: t,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(t),
                child: child,
              ),
            );
          },
        );
}
