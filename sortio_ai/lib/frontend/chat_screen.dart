// ============================================================================
// Sortio AI — frontend/chat_screen.dart
//
// The chat screen: status bar, header, feed and composer, plus the toast.
// It is embedded by HomeShell (the "+" button in the navigation bar) — no
// Scaffold of its own, so the nav bar stays visible. The controller is shared
// with the rest of the app via the shell.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/motion.dart';
import 'chat_composer.dart';
import 'chat_feed.dart';
import 'chat_header.dart';
import 'toast.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});

  /// Shared app state, owned by [HomeShell].
  final SortioController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  SortioController get _controller => widget.controller;

  /// Text fields are wired to stable [TextEditingController]s so the cursor
  /// never jumps: values are pushed into the model via `onChanged`, and pushed
  /// back into the field only when the model changed externally (e.g. the
  /// composer is cleared after sending).
  late final TextEditingController _composerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncTextFields);
  }

  void _syncTextFields() {
    if (_composerCtrl.text != _controller.composerText) {
      _composerCtrl.text = _controller.composerText;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextFields);
    _composerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            // -- Main column ---------------------------------------------
            SafeArea(
              child: Column(
                children: [
                  SortioHeaderBar(controller: _controller),
                  Expanded(child: SortioChatFeed(controller: _controller)),
                  SortioComposerBar(
                    controller: _controller,
                    composerController: _composerCtrl,
                  ),
                ],
              ),
            ),

            // -- Toast ---------------------------------------------------
            Positioned(
              left: 16,
              right: 16,
              bottom: 104,
              child: IgnorePointer(
                child: AnimatedSlide(
                  duration: SortioMotion.toast,
                  curve: SortioMotion.slideIn,
                  offset: _controller.toastOn ? Offset.zero : const Offset(0, 0.25),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _controller.toastOn ? 1 : 0,
                    child: SortioToast(text: _controller.toastText),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
