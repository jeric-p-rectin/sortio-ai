// ============================================================================
// Sortio AI — frontend/chat_composer.dart
//
// The bottom composer: attach (+) button, message input and send button.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import 'shared_widgets.dart';

class SortioComposerBar extends StatelessWidget {
  const SortioComposerBar({super.key, required this.controller, required this.composerController});

  final SortioController controller;
  final TextEditingController composerController;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: SortioColors.page,
        border: Border(top: BorderSide(color: SortioColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SortioColors.border),
            ),
            child: Row(
              children: [
                SortioPressScale(
                  onTap: c.onAttachTapped,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SortioColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: SortioColors.borderTile),
                    ),
                    child: const Icon(Icons.add, size: 20, color: SortioColors.textBody),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: composerController,
                      onChanged: c.setComposerText,
                      onSubmitted: (_) => c.sendMessage(),
                      textInputAction: TextInputAction.send,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14.5, color: Color(0xFFF1F5F9)),
                      cursorColor: SortioColors.accent,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Ask Sortio to find or tidy files…',
                        hintStyle: TextStyle(fontSize: 14.5, color: SortioColors.textMuted),
                      ),
                    ),
                  ),
                ),
                SortioPressScale(
                  onTap: c.sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: SortioColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, size: 19, color: SortioColors.onAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
