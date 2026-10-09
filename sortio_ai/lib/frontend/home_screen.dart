// ============================================================================
// Sortio AI — frontend/home_screen.dart
//
// Screen: Home — greeting, savings stats, quick actions that jump into the
// chat (or Settings), and a preview of recent chats.
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

  @override
  Widget build(BuildContext context) {
    final s = controller.savings;
    final chats = SortioData.chatSessions().take(3).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -- Header ---------------------------------------------------
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/images/sortio_logo.png',
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sortio AI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: SortioColors.textBright,
                        ),
                      ),
                      Text(
                        'Your files, tidy — and private',
                        style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                      ),
                    ],
                  ),
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

            // -- Recent chats ------------------------------------------------
            Row(
              children: [
                const Expanded(child: SortioSectionLabel('Recent chats')),
                _SeeAllButton(onTap: navigation.openHistory),
              ],
            ),
            const SizedBox(height: 10),
            for (final chat in chats) ...[
              _ChatPreviewRow(session: chat),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SortioColors.textBody),
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
      child: Row(
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

class _ChatPreviewRow extends StatelessWidget {
  const _ChatPreviewRow({required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context) {
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
            child: Icon(Icons.chat_bubble_outline, size: 17, color: SortioColors.accentBright),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SortioColors.textBody),
                ),
                const SizedBox(height: 2),
                Text(
                  session.when,
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
