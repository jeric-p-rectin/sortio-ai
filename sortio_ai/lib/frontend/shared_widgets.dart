// ============================================================================
// Sortio AI — frontend/shared_widgets.dart
//
// Small widgets shared across screens: the 44px icon button, the uppercase
// section label, and the press-scale tap feedback.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/design_tokens.dart';

/// The 44x44 rounded icon button (`.icon-btn` in the prototype).
class SortioIconButton extends StatelessWidget {
  const SortioIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 22, color: SortioColors.textSoft),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Uppercase section label (`.sec` in the prototype).
class SortioSectionLabel extends StatelessWidget {
  const SortioSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w600,
        color: SortioColors.textMuted,
      ),
    );
  }
}

/// Press feedback matching `.btn:active { transform: scale(.97) }`.
class SortioPressScale extends StatefulWidget {
  const SortioPressScale({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<SortioPressScale> createState() => _SortioPressScaleState();
}

class _SortioPressScaleState extends State<SortioPressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// One number + unit + caption tile, used by the Savings Summary and Home.
class SortioStatCell extends StatelessWidget {
  const SortioStatCell({
    super.key,
    required this.value,
    required this.unit,
    required this.unitColor,
    required this.label,
  });

  final String value;
  final String unit;
  final Color? unitColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: SortioColors.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SortioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: SortioColors.textBright,
                ),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: unitColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, height: 1.3, color: SortioColors.textMuted),
          ),
        ],
      ),
    );
  }
}
