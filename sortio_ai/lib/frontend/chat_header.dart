// ============================================================================
// Sortio AI — frontend/chat_header.dart
//
// The chat header: Sortio AI logo + title and a new-chat button.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import 'shared_widgets.dart';

class SortioHeaderBar extends StatelessWidget {
  const SortioHeaderBar({super.key, required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: SortioColors.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/images/sortio_logo.png',
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Sortio AI',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: SortioColors.textBright,
            ),
          ),
          const Spacer(),
          SortioIconButton(
            icon: Icons.add_comment_outlined,
            tooltip: 'New chat',
            onPressed: c.startNewChat,
          ),
        ],
      ),
    );
  }
}
