// ============================================================================
// Sortio AI — frontend/home_screen.dart
//
// Screen: Home — greeting, savings stats, quick actions that jump into the
// chat (or Settings), and a preview of recent on-device activity.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/data_output.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import '../backend/navigation.dart';
import 'shared_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller, required this.navigation});

  final SortioController controller;
  final SortioNavigationController navigation;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.savings;
    final history = SortioData.history().take(3).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Header ---------------------------------------------------
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SortioColors.accent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.sort, size: 22, color: SortioColors.onAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: SortioColors.textBright,
                        ),
                      ),
                      const Text(
                        'Your files, tidy — and private',
                        style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                      ),
                    ],
                  ),
                ),
                SortioIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Open settings',
                  onPressed: navigation.openSettings,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // -- Savings stats ---------------------------------------------
            Row(
              children: [
                Expanded(
                  child: SortioStatCell(value: '${s.files}', unit: '', unitColor: null, label: 'files organized'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SortioStatCell(value: '${s.mbFreed}', unit: 'MB', unitColor: SortioColors.accentBright, label: 'freed'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SortioStatCell(value: '${s.minutesSaved}', unit: 'min', unitColor: SortioColors.greenBright, label: 'saved'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 12, color: SortioColors.textMuted),
                SizedBox(width: 6),
                Text(
                  '0 bytes uploaded · 100% on-device',
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // -- Quick actions ---------------------------------------------
            const SortioSectionLabel('Quick actions'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                _QuickAction(
                  icon: Icons.auto_fix_high_outlined,
                  label: 'Tidy Downloads',
                  tint: SortioColors.accentBright,
                  onTap: navigation.openChat,
                ),
                _QuickAction(
                  icon: Icons.search,
                  label: 'Find a file',
                  tint: SortioColors.accentBright,
                  onTap: navigation.openChat,
                ),
                _QuickAction(
                  icon: Icons.camera_alt_outlined,
                  label: 'Scan a document',
                  tint: SortioColors.accentBright,
                  onTap: navigation.openChat,
                ),
                _QuickAction(
                  icon: Icons.verified_user_outlined,
                  label: 'Privacy check',
                  tint: SortioColors.greenBright,
                  onTap: navigation.openSettings,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // -- Recent activity -------------------------------------------
            Row(
              children: [
                const Expanded(child: SortioSectionLabel('Recent activity')),
                _SeeAllButton(onTap: navigation.openHistory),
              ],
            ),
            const SizedBox(height: 10),
            for (final entry in history) ...[
              _HistoryPreviewRow(entry: entry),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.tint, required this.onTap});

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SortioPressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: SortioColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SortioColors.borderCard),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SortioColors.well,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SortioColors.borderTile),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SortioColors.textBody),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'See all',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SortioColors.accentSoft),
          ),
          SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 16, color: SortioColors.accentSoft),
        ],
      ),
    );
  }
}

class _HistoryPreviewRow extends StatelessWidget {
  const _HistoryPreviewRow({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final toneColor = entry.tone == SuggestionTone.amber ? SortioColors.amber : SortioColors.accentBright;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SortioColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SortioColors.borderCard),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: Icon(Icons.check_circle_outline, size: 17, color: toneColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SortioColors.textBody),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.when,
                  style: const TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
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
    );
  }
}
