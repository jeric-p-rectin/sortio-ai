// ============================================================================
// Sortio AI — frontend/chat_header.dart
//
// The chat header: Sortio AI logo + title and the live model line (driven by
// the engine's real on-device network status).
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';

class SortioHeaderBar extends StatelessWidget {
  const SortioHeaderBar({super.key, required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SortioColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: SortioColors.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.sort, size: 14, color: SortioColors.onAccent),
          ),
          const SizedBox(width: 8),
          const Text(
            'Sortio AI',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: SortioColors.textBright,
            ),
          ),
          const Spacer(),
          // Flexible (not a bare Row) so the nested Row gets a bounded width —
          // a plain Row child of a Row would receive an unbounded constraint.
          Flexible(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: SortioColors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SortioColors.green.withValues(alpha: 0.2),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    c.modelLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: SortioColors.textMuted),
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
