// ============================================================================
// Sortio AI — frontend/chat_feed.dart
//
// The conversation feed: date chip, user/agent bubbles, the scripted opening
// exchange, the suggestion blocks (card -> collapse -> applied/ignored row),
// extra conversation, and the typing indicator. Auto-scrolls on new content.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/animations.dart';
import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import '../backend/motion.dart';
import 'suggestion_card.dart';

class SortioChatFeed extends StatefulWidget {
  const SortioChatFeed({super.key, required this.controller});

  final SortioController controller;

  @override
  State<SortioChatFeed> createState() => _SortioChatFeedState();
}

class _SortioChatFeedState extends State<SortioChatFeed> {
  final ScrollController _scroll = ScrollController();
  int _lastExtraCount = 0;
  bool _lastTyping = false;
  bool _lastAllResolved = false;

  SortioController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_maybeScroll);
  }

  @override
  void dispose() {
    c.removeListener(_maybeScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeScroll() {
    final changed = c.extraMessages.length != _lastExtraCount ||
        c.typing != _lastTyping ||
        c.allResolved != _lastAllResolved;
    _lastExtraCount = c.extraMessages.length;
    _lastTyping = c.typing;
    _lastAllResolved = c.allResolved;
    if (!changed || !_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: SortioMotion.slideIn,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildItems(context),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    final items = <Widget>[];

    void add(Widget w) {
      if (items.isNotEmpty) items.add(const SizedBox(height: 12));
      items.add(w);
    }

    // Date chip
    add(const Align(
      alignment: Alignment.center,
      child: _DateChip(),
    ));

    // Scripted opening exchange
    add(const _UserBubble('Find my Meralco bill from March and tidy my recent downloads.'));
    add(const _AgentBubble('Found your bill and 2 other files. Here are my suggestions:'));

    // Suggestion blocks (card -> collapse -> applied/ignored row)
    for (final s in c.suggestions.values) {
      add(_SuggestionBlock(suggestion: s, controller: c));
    }

    // Wrap-up agent line once both cards are resolved
    if (c.allResolved) {
      add(_AgentBubble(c.doneLine));
    }

    // Extra conversation
    for (final m in c.extraMessages) {
      add(m.isUser ? _UserBubble(m.text) : _AgentBubble(m.text));
    }

    // Typing indicator
    if (c.typing) {
      add(const _TypingRow());
    }

    return items;
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: SortioColors.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SortioColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.crop_free, size: 14, color: SortioColors.accentBright),
          SizedBox(width: 8),
          Text(
            'Today · on-device session',
            style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopIn(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.82),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: SortioColors.green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentBubble extends StatelessWidget {
  const _AgentBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      child: _AgentRow(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.widthOf(context) * 0.82),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: SortioColors.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 14.5, height: 1.45, color: SortioColors.textBody),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar + bubble row (aligns bubble to the avatar's bottom edge).
class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: SortioColors.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: SortioColors.borderTile),
          ),
          child: const Icon(Icons.sort, size: 15, color: SortioColors.accent),
        ),
        const SizedBox(width: 10),
        Flexible(child: child),
      ],
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return PopIn(
      child: _AgentRow(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: const BoxDecoration(
            color: SortioColors.card,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: const TypingDots(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Suggestion block: card + collapse + applied/ignored row
// ---------------------------------------------------------------------------

class _SuggestionBlock extends StatelessWidget {
  const _SuggestionBlock({required this.suggestion, required this.controller});

  final Suggestion suggestion;
  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final c = controller;
    return Padding(
      padding: const EdgeInsets.only(left: 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapseOut(
            collapsed: s.closing || !s.isPending,
            child: SuggestionCard(suggestion: s, controller: c),
          ),
          if (s.state == SuggestionState.applied)
            CollapseOut(
              collapsed: false,
              child: PopIn(child: SortioDoneRow.applied(s, c)),
            )
          else if (s.state == SuggestionState.ignored)
            CollapseOut(
              collapsed: false,
              child: PopIn(child: SortioDoneRow.ignored(s, c)),
            ),
        ],
      ),
    );
  }
}
