// ============================================================================
// Sortio AI — frontend/chat_screen.dart
//
// The main screen: orchestrates the status bar, header, chat feed and
// composer column, plus the three overlays (scrim, sessions drawer, privacy
// sheet) and the toast — exactly like the prototype's phone canvas.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/motion.dart';
import 'chat_composer.dart';
import 'chat_feed.dart';
import 'chat_header.dart';
import 'privacy_sheet.dart';
import 'sessions_drawer.dart';
import 'status_bar.dart';
import 'toast.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.initialPanel = StartPanel.none});

  /// Mirrors the prototype's `startPanel` prop (none | drawer | settings).
  final StartPanel initialPanel;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final SortioController _controller =
      SortioController(initialPanel: widget.initialPanel);

  /// Text fields are wired to stable [TextEditingController]s so the cursor
  /// never jumps: values are pushed into the model via `onChanged`, and pushed
  /// back into the field only when the model changed externally (e.g. the
  /// composer is cleared after sending, rules are wiped by the nuke button).
  late final TextEditingController _composerCtrl = TextEditingController();
  late final TextEditingController _rulesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncTextFields);
  }

  void _syncTextFields() {
    if (_composerCtrl.text != _controller.composerText) {
      _composerCtrl.text = _controller.composerText;
    }
    if (_rulesCtrl.text != _controller.rules) {
      _rulesCtrl.text = _controller.rules;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTextFields);
    _composerCtrl.dispose();
    _rulesCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final panelOpen = c.drawerOpen || c.sheetOpen;
        return Scaffold(
          backgroundColor: SortioColors.page,
          body: Stack(
            children: [
              // -- Main column -------------------------------------------
              SafeArea(
                child: Column(
                  children: [
                    SortioStatusBar(offline: c.offline),
                    SortioHeaderBar(controller: c),
                    Expanded(child: SortioChatFeed(controller: c)),
                    SortioComposerBar(controller: c, composerController: _composerCtrl),
                  ],
                ),
              ),

              // -- Scrim -------------------------------------------------
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !panelOpen,
                  child: AnimatedOpacity(
                    duration: SortioMotion.scrim,
                    opacity: panelOpen ? 1 : 0,
                    child: GestureDetector(
                      onTap: c.closePanels,
                      child: const ColoredBox(color: SortioColors.scrim),
                    ),
                  ),
                ),
              ),

              // -- Sessions drawer ---------------------------------------
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedSlide(
                  duration: SortioMotion.drawer,
                  curve: SortioMotion.slideIn,
                  offset: c.drawerOpen ? Offset.zero : const Offset(-1.04, 0),
                  child: SafeArea(
                    child: SessionsDrawer(controller: c),
                  ),
                ),
              ),

              // -- Privacy Command Center sheet --------------------------
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSlide(
                    duration: SortioMotion.sheet,
                    curve: SortioMotion.slideIn,
                    offset: c.sheetOpen ? Offset.zero : const Offset(0, 1.04),
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: 0.88,
                      child: SafeArea(
                        top: false,
                        child: PrivacySheet(controller: c, rulesController: _rulesCtrl),
                      ),
                    ),
                  ),
                ),
              ),

              // -- Toast -------------------------------------------------
              Positioned(
                left: 16,
                right: 16,
                bottom: 104,
                child: IgnorePointer(
                  child: AnimatedSlide(
                    duration: SortioMotion.toast,
                    curve: SortioMotion.slideIn,
                    offset: c.toastOn ? Offset.zero : const Offset(0, 0.25),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: c.toastOn ? 1 : 0,
                      child: SortioToast(text: c.toastText),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
