// ============================================================================
// Sortio AI — frontend/history_screen.dart
//
// Screen: History — the chat history. Every conversation with Sortio is a
// row here; tapping one reopens it in the chat screen.
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
                          return _SwipeToDelete(
                            key: ValueKey(chats[i].id),
                            // The gap lives inside the row so it collapses
                            // together with the card when it is deleted.
                            bottomGap: i == chats.length - 1 ? 0 : 10,
                            onDelete: () => controller.deleteSession(chats[i].id),
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

enum _Exit { none, slide, fade }

/// Swipe a card left to reveal a trash button.
///
/// * A short swipe opens the trash button. Tapping it fades the card out and
///   then collapses its row.
/// * A long swipe, all the way to the left, deletes the card without the
///   button: it keeps sliding off to the left until it has vanished, then its
///   row collapses.
///
/// Swiping back (or releasing short of the halfway point) closes it again.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.bottomGap = 0,
  });

  final Widget child;
  final VoidCallback onDelete;

  /// Space kept under the card. It lives in here so it collapses with the row.
  final double bottomGap;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> with SingleTickerProviderStateMixin {
  static const double _actionWidth = 64;
  static const double _gap = 10;
  static const double _openExtent = _actionWidth + _gap;

  /// While the card is being dragged, the red layer reaches this far under it
  /// (hidden by the card), so no page background shows through the card's
  /// rounded corners: it reads as one layer sliding over another.
  static const double _tuck = 20;

  /// Releasing a drag past this fraction of the card's width deletes it.
  static const double _fullSwipe = 0.55;

  /// A fast fling (px/s) that has travelled at least [_flingFloor] of the
  /// width also deletes it.
  static const double _flingSpeed = 1800;
  static const double _flingFloor = 0.35;

  /// The exit is one run: first the card leaves (slides off to the left, or
  /// fades), then the empty row collapses. [_leaveShare] is the first part.
  static const Duration _exitDuration = Duration(milliseconds: 480);
  static const double _leaveShare = 0.5;

  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: _exitDuration,
  );

  double _dx = 0;
  bool _dragging = false;
  _Exit _exit = _Exit.none;
  double _exitFrom = 0;

  bool get _open => _dx <= -_openExtent / 2;

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_exit != _Exit.none) return;
    setState(() {
      _dragging = true;
      _dx = (_dx + d.delta.dx).clamp(-width, 0.0).toDouble();
    });
  }

  void _onDragEnd(DragEndDetails d, double width) {
    if (_exit != _Exit.none) return;
    final v = d.primaryVelocity ?? 0;

    // All the way to the left: delete it, no button needed.
    final pulledFar = -_dx >= width * _fullSwipe;
    final flung = v < -_flingSpeed && -_dx >= width * _flingFloor;
    if (pulledFar || flung) {
      _dismiss(_Exit.slide);
      return;
    }

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

  /// Plays the exit animation, then deletes for real once the row is gone.
  void _dismiss(_Exit kind) {
    if (_exit != _Exit.none) return;
    setState(() {
      _exit = kind;
      _dragging = false;
      _exitFrom = _dx;
    });
    _out.forward().then((_) {
      if (mounted) widget.onDelete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return AnimatedBuilder(
          animation: _out,
          builder: (context, _) {
            final t = _out.value;
            final leave = (t / _leaveShare).clamp(0.0, 1.0).toDouble();
            final collapse = Curves.easeInOutCubic.transform(
              ((t - _leaveShare) / (1 - _leaveShare)).clamp(0.0, 1.0).toDouble(),
            );
            final slideT = Curves.easeInCubic.transform(leave);
            final fadeT = Curves.easeInOut.transform(leave);
            final opacity = (_exit == _Exit.fade ? 1 - fadeT : 1.0) * (1 - collapse);

            return ClipRect(
              clipper: const _RowClipper(),
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1 - collapse,
                child: Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: widget.bottomGap),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
                      onHorizontalDragEnd: (d) => _onDragEnd(d, width),
                      // The card's offset is animated here (instant while the
                      // finger is down), so the trash area and the card always
                      // move together.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: _dx),
                        duration: _dragging || _exit != _Exit.none
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        builder: (context, settled, _) {
                          // A full swipe keeps going until the card is off
                          // screen (list padding included).
                          final dx = _exit == _Exit.slide
                              ? lerpDouble(_exitFrom, -(width + 24), slideT)!
                              : settled;
                          return _stack(width, dx);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _stack(double width, double dx) {
    // r = how much of the row the card has uncovered on the right.
    final r = (-dx).clamp(0.0, width).toDouble();

    // While the finger is down (or the card is leaving) the red layer sits
    // flush under the card, like a layer being opened. Once the card rests
    // half-open, the layer separates into a button with a gap.
    final separated = !_dragging && _exit != _Exit.slide && _dx <= -1;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: separated ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, gapT, _) {
        final gap = _gap * gapT;
        final tuck = math.min(_tuck, r) * (1 - gapT);
        final visibleLeft = width - r + gap;
        final left = math.max(0.0, visibleLeft - tuck);
        // The icon sits in a 64 px slot at the right; once the card is pulled
        // past the open position it trails the card's edge.
        final iconCenter = math.min(visibleLeft + _actionWidth / 2, width - _actionWidth / 2);
        final iconOpacity = (r / 28).clamp(0.0, 1.0).toDouble();
        final shadowT = (r / 24).clamp(0.0, 1.0).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Red trash layer, underneath the card.
            Positioned(
              top: 0,
              bottom: 0,
              left: left,
              right: 0,
              child: SortioPressScale(
                onTap: () => _dismiss(_Exit.fade),
                child: Container(
                  decoration: BoxDecoration(
                    color: SortioColors.redArm,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: iconCenter - left - 11,
                        top: 0,
                        bottom: 0,
                        width: 22,
                        child: Opacity(
                          opacity: iconOpacity,
                          child: const Center(
                            child: Icon(Icons.delete_outline, size: 22, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The card, on top. Its soft shadow falls on the red layer.
            Transform.translate(
              offset: Offset(dx, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32 * shadowT),
                      blurRadius: 12,
                      spreadRadius: -3,
                      offset: const Offset(6, 0),
                    ),
                  ],
                ),
                child: _exit != _Exit.none
                    ? IgnorePointer(child: widget.child)
                    : _dx == 0
                        ? widget.child
                        // While open, a tap on the card just closes it.
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _close,
                            child: AbsorbPointer(child: widget.child),
                          ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Clips only vertically (while a row collapses); the card stays free to slide
/// out sideways over the list padding.
class _RowClipper extends CustomClipper<Rect> {
  const _RowClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-4000, 0, size.width + 4000, size.height);

  @override
  bool shouldReclip(_RowClipper oldClipper) => false;
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
