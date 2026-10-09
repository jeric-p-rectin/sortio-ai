// ============================================================================
// Sortio AI — frontend/toast.dart
//
// The toast banner shown above the composer (slide + fade in/out).
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/design_tokens.dart';

class SortioToast extends StatelessWidget {
  const SortioToast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SortioColors.toastBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortioColors.accent.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(color: Color(0xBF000000), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -12),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.verified_user, size: 18, color: SortioColors.accentBright),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45, color: SortioColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}
