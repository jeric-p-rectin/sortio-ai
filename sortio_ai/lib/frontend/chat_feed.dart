// ============================================================================
// Sortio AI — frontend/chat_feed.dart
//
// The conversation feed: user/agent bubbles of the active chat session, the
// scripted demo conversation with its suggestion blocks (card -> collapse ->
// applied/ignored row), a welcome state for brand-new chats, and the typing
// indicator. Auto-scrolls on new content.
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
  String? _lastSessionId;
  int _lastMessageCount = 0;
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
    final sessionId = c.activeSession?.id;
    final messageCount = c.activeSession?.messages.length ?? 0;
    final allResolved = c.isScriptedChat && c.allResolved;
    final changed = sessionId != _lastSessionId ||
        messageCount != _lastMessageCount ||
        c.typing != _lastTyping ||
        allResolved != _lastAllResolved;
    _lastSessionId = sessionId;
    _lastMessageCount = messageCount;
    _lastTyping = c.typing;
    _lastAllResolved = allResolved;
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

    final session = c.activeSession;

    // Brand-new chat: nothing recorded yet — show the welcome state.
    if (session == null) {
      items.add(const _NewChatHero());
      return items;
    }

    final messages = session.messages;

    if (c.isScriptedChat) {
      // The scripted opening exchange, then its suggestion blocks, then the
      // rest of the conversation.
      for (final m in messages.take(2)) {
        add(m.isUser ? _UserBubble(m.text) : _AgentBubble(m.text));
      }

      // Suggestion blocks (card -> collapse -> applied/ignored row)
      for (final s in c.suggestions.values) {
        add(_SuggestionBlock(suggestion: s, controller: c));
      }

      // Wrap-up agent line once both cards are resolved
      if (c.allResolved) {
        add(_AgentBubble(c.doneLine));
      }

      for (final m in messages.skip(2)) {
        add(m.isUser ? _UserBubble(m.text) : _AgentBubble(m.text));
      }
    } else {
      for (final m in messages) {
        add(m.isUser ? _UserBubble(m.text) : _AgentBubble(m.text));
      }
    }

    // Typing indicator — only for the conversation waiting on a reply.
    if (c.typing && c.typingSessionId == session.id) {
      add(const _TypingRow());
    }

    return items;
  }
}

/// Welcome state for a brand-new chat, before the first message is sent.
class _NewChatHero extends StatelessWidget {
  const _NewChatHero();

  @override
  Widget build(BuildContext context) {
    context.watchSortioTheme();
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.heightOf(context) * 0.16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/sortio_logo.png',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'How can I help you sort your files?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: SortioColors.textBright,
            ),
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
            decoration: BoxDecoration(
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
            decoration: BoxDecoration(
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
              style: TextStyle(fontSize: 14.5, height: 1.45, color: SortioColors.textBody),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/sortio_logo.png',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
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
    context.watchSortioTheme();
    return PopIn(
      child: _AgentRow(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
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
