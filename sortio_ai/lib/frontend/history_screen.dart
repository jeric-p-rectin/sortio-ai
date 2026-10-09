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
                    Expanded(
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
                            child: _SwipeToDelete(
                              key: ValueKey(chats[i].id),
                              onDelete: () => controller.deleteSession(chats[i].id),
                              child: _ChatRow(
                                session: chats[i],
                                active: controller.activeSession?.id == chats[i].id,
                                onTap: () {
                                  controller.openSession(chats[i].id);
                                  navigation.openChat();
                                },
                              ),
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
        child: Row(
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

/// Swipe a card left to reveal a trash button; tapping the button deletes it.
/// Swiping back (or releasing short of the threshold) closes it again.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({super.key, required this.child, required this.onDelete});

  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  static const double _actionWidth = 64;
  static const double _gap = 10;
  static const double _openExtent = _actionWidth + _gap;

  double _dx = 0;
  bool _dragging = false;

  bool get _open => _dx <= -_openExtent / 2;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragging = true;
      _dx = (_dx + d.delta.dx).clamp(-_openExtent, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    setState(() {
      _dragging = false;
      if (v < -300) {
        _dx = -_openExtent;
      } else if (v > 300) {
        _dx = 0;
      } else {
        _dx = _open ? -_openExtent : 0;
      }
    });
  }

  void _close() => setState(() => _dx = 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // Trash button, revealed behind the card as it slides left.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SortioPressScale(
                onTap: widget.onDelete,
                child: Container(
                  width: _actionWidth,
                  decoration: BoxDecoration(
                    color: SortioColors.redArm,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.delete_outline, size: 22, color: Colors.white),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: _dx == 0
                ? widget.child
                // While open, a tap on the card just closes it.
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: AbsorbPointer(child: widget.child),
                  ),
          ),
        ],
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
              child: Icon(Icons.chat_bubble_outline, size: 18, color: SortioColors.accentBright),
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
                    style: TextStyle(
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
                    style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.when,
              style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
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
            Text(
              'No chats yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SortioColors.textBright),
            ),
            const SizedBox(height: 4),
            Text(
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
