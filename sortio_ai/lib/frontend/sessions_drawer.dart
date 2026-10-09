// ============================================================================
// Sortio AI â€” frontend/sessions_drawer.dart
//
// Screen: the slide-in Sessions drawer â€” session list (Current / Recent) and
// the Savings Summary card (files organized, space freed, time saved).
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import 'shared_widgets.dart';

// The Savings Summary card here shares [SortioStatCell] with the Home screen.

class SessionsDrawer extends StatelessWidget {
  const SessionsDrawer({super.key, required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: 310,
      padding: const EdgeInsets.fromLTRB(14, 40, 14, 16),
      decoration: const BoxDecoration(
        color: SortioColors.panel,
        border: Border(right: BorderSide(color: SortioColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0xD9000000), offset: Offset(30, 0), blurRadius: 60, spreadRadius: -24),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Sessions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: SortioColors.textBright,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'History lives only on this phone',
                        style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                      ),
                    ],
                  ),
                ),
                SortioIconButton(icon: Icons.close, tooltip: 'Close sessions', onPressed: c.closePanels),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sessions list
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < c.sessions.length; i++) ...[
                    if (i == 0 || c.sessions[i - 1].section != c.sessions[i].section)
                      Padding(
                        padding: EdgeInsets.fromLTRB(6, i == 0 ? 4 : 12, 6, 4),
                        child: SortioSectionLabel(c.sessions[i].section),
                      ),
                    _SessionTile(
                      entry: c.sessions[i],
                      controller: c,
                      active: c.activeSession == c.sessions[i].id,
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),

          // Savings summary
          _SavingsSummaryCard(controller: c),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.entry, required this.controller, required this.active});

  final SessionEntry entry;
  final SortioController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final toneColor = entry.tone == SuggestionTone.amber ? SortioColors.amber : SortioColors.accentBright;
    return SortioPressScale(
      onTap: () => controller.pickSession(entry.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? SortioColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? SortioColors.borderSession : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SortioColors.card,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: SortioColors.borderTile),
              ),
              child: Icon(_iconFor(entry.id), size: 18, color: toneColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SortioColors.textBody),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: TextStyle(fontSize: 12, color: entry.tone == SuggestionTone.amber ? SortioColors.amber : SortioColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String id) => switch (id) {
        'now' => Icons.auto_awesome,
        'tax' => Icons.receipt_long_outlined,
        'weekly' => Icons.download_outlined,
        _ => Icons.badge_outlined,
      };
}

class _SavingsSummaryCard extends StatelessWidget {
  const _SavingsSummaryCard({required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.savings;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SortioColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SortioColors.borderTile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Savings Summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SortioColors.textBright),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: SortioColors.accent.withValues(alpha: 0.45)),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SortioColors.accentSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SortioStatCell(
                  value: '${s.files}',
                  unit: '',
                  unitColor: null,
                  label: 'files organized',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SortioStatCell(
                  value: '${s.mbFreed}',
                  unit: 'MB',
                  unitColor: SortioColors.accentBright,
                  label: 'freed',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SortioStatCell(
                  value: '${s.minutesSaved}',
                  unit: 'min',
                  unitColor: SortioColors.greenBright,
                  label: 'saved',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 12, color: SortioColors.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '0 bytes uploaded Â· 100% on-device',
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
