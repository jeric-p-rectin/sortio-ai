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
      decoration: BoxDecoration(
        color: SortioColors.page,
        border: Border(top: BorderSide(color: SortioColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: SortioColors.border),
            ),
            child: Row(
              // Buttons stay pinned to the bottom edge; as the input grows the
              // bar extends upwards only.
              crossAxisAlignment: CrossAxisAlignment.end,
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
                    child: Icon(Icons.add, size: 20, color: SortioColors.textBody),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      child: TextField(
                        controller: composerController,
                        onChanged: c.setComposerText,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textAlign: TextAlign.start,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(fontSize: 14.5, height: 1.3, color: SortioColors.textBody),
                        cursorColor: SortioColors.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          hintText: 'Ask Sortio to find or tidy files…',
                          hintStyle: TextStyle(fontSize: 14.5, height: 1.3, color: SortioColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),
                SortioPressScale(
                  onTap: c.sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SortioColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, size: 19, color: SortioColors.onAccent),
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
