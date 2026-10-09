// ============================================================================
// Sortio AI — frontend/status_bar.dart
//
// The in-canvas status bar from the prototype (10:24, wifi state, signal,
// battery 82%). Its wifi icon doubles as the offline-mode indicator.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/design_tokens.dart';

class SortioStatusBar extends StatelessWidget {
  const SortioStatusBar({super.key, required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 20),
        child: Row(
          children: [
            const Text(
              '10:24',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SortioColors.textBody),
            ),
            const Spacer(),
            Icon(
              offline ? Icons.wifi_off : Icons.wifi,
              size: 15,
              color: SortioColors.textSoft,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.signal_cellular_4_bar, size: 15, color: SortioColors.textSoft),
            const SizedBox(width: 6),
            const Icon(Icons.battery_6_bar, size: 18, color: SortioColors.textSoft),
            const SizedBox(width: 6),
            const Text('82%', style: TextStyle(fontSize: 12, color: SortioColors.textSoft)),
          ],
        ),
      ),
    );
  }
}
