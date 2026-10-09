// ============================================================================
// Sortio AI — frontend/history_screen.dart
//
// Screen: History — the on-device action log. Everything Sortio has done,
// each entry with its action chip and timestamp. Nothing ever left the phone.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/data_output.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import '../backend/navigation.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.navigation});

  final SortioNavigationController navigation;

  @override
  Widget build(BuildContext context) {
    final entries = SortioData.history();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- Header ------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: SortioColors.textBright,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every action, logged on this device only.',
                  style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // -- Log ----------------------------------------------------------
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 10),
                  child: _HistoryCard(entry: entries[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final toneColor = entry.tone == SuggestionTone.amber ? SortioColors.amber : SortioColors.accentBright;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SortioColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortioColors.borderCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: Icon(_iconFor(entry.chip), size: 18, color: toneColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SortioColors.textBody,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: toneColor.withValues(alpha: 0.4)),
                        color: toneColor.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        entry.chip,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: toneColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: SortioColors.textMuted,
                    fontFamily: SortioFonts.mono,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.when,
                  style: const TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String chip) => switch (chip) {
        'Rename' => Icons.drive_file_rename_outline,
        'Quarantine' => Icons.shield_outlined,
        'Cleanup' => Icons.auto_fix_high_outlined,
        'Search' => Icons.search,
        'Sensitive' => Icons.badge_outlined,
        _ => Icons.delete_outline,
      };
}
