// ============================================================================
// Sortio AI — frontend/history_screen.dart
//
// Screen: History — the chat history. Every conversation with Sortio is a
// row here; tapping one reopens it in the chat screen.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import '../backend/navigation.dart';
import 'shared_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller, required this.navigation});

  final SortioController controller;
  final SortioNavigationController navigation;

  void _startNewChat() {
    controller.startNewChat();
    navigation.openChat();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final chats = controller.chatSessions;

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Header ------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'History',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: SortioColors.textBright,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Your conversations with Sortio.',
                            style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    _NewChatButton(onTap: _startNewChat),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // -- Chats -------------------------------------------------------
              Expanded(
                child: chats.isEmpty
                    ? _EmptyChats(onStart: _startNewChat)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: chats.length,
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == chats.length - 1 ? 0 : 10),
                            child: _ChatRow(
                              session: chats[i],
                              active: controller.activeSession?.id == chats[i].id,
                              onTap: () {
                                controller.openSession(chats[i].id);
                                navigation.openChat();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SortioPressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: SortioColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SortioColors.accent.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: SortioColors.accentBright),
            SizedBox(width: 6),
            Text(
              'New chat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SortioColors.accentBright),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.session, required this.active, required this.onTap});

  final ChatSession session;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SortioPressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SortioColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? SortioColors.accent.withValues(alpha: 0.45) : SortioColors.borderCard,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SortioColors.well,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: SortioColors.borderTile),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 18, color: SortioColors.accentBright),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SortioColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    session.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: SortioColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.when,
              style: const TextStyle(fontSize: 11, color: SortioColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the chat history is empty.
class _EmptyChats extends StatelessWidget {
  const _EmptyChats({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/sortio_logo.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SortioColors.textBright),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask Sortio something and the conversation will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
            ),
            const SizedBox(height: 16),
            _NewChatButton(onTap: onStart),
          ],
        ),
      ),
    );
  }
}
