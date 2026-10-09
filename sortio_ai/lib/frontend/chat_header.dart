// ============================================================================
// Sortio AI — frontend/chat_header.dart
//
// The app header: sessions menu, Sortio AI logo + live model line, the
// "Offline Mode" toggle pill, and the privacy-settings button.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/animations.dart';
import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import 'shared_widgets.dart';

class SortioHeaderBar extends StatelessWidget {
  const SortioHeaderBar({super.key, required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SortioColors.border)),
      ),
      child: Row(
        children: [
          SortioIconButton(
            icon: Icons.menu,
            tooltip: 'Open sessions',
            onPressed: c.openDrawer,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
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
                ],
              ),
            ),
          ),
          // Offline Mode pill
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 40,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: c.offline
                    ? SortioColors.accent.withValues(alpha: 0.55)
                    : SortioColors.borderStrong,
              ),
              boxShadow: c.offline
                  ? [BoxShadow(color: SortioColors.accent.withValues(alpha: 0.12), spreadRadius: 4)]
                  : const [],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: c.toggleNetwork,
                  child: const Text(
                    'Offline Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SortioColors.textSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SortioSwitch(
                  value: c.offline,
                  onChanged: (_) => c.toggleNetwork(),
                  width: 32,
                  height: 20,
                  trackWidth: 32,
                  trackHeight: 20,
                  thumbSize: 14,
                  trackOn: SortioColors.accent,
                  thumbOn: SortioColors.page,
                  thumbOff: SortioColors.textMuted,
                ),
              ],
            ),
          ),
          SortioIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Open privacy settings',
            onPressed: c.openSheet,
          ),
        ],
      ),
    );
  }
}
