// ============================================================================
// Sortio AI — frontend/settings_screen.dart
//
// Screen: Settings — the Privacy Command Center as a full page. Folder
// sandbox, AI strictness, house rules and the danger zone (memory wipe).
// Shares the app-wide SortioController so these settings drive the chat.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/animations.dart';
import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import 'shared_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final SortioController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _rulesCtrl = TextEditingController(text: widget.controller.rules);

  SortioController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_syncRules);
  }

  void _syncRules() {
    // Push externally-changed values back into the field (e.g. the memory
    // wipe clears the rules); never fight the user's own typing.
    if (_rulesCtrl.text != c.rules) {
      _rulesCtrl.text = c.rules;
    }
  }

  @override
  void dispose() {
    c.removeListener(_syncRules);
    _rulesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strict = c.strictOutput;
    return SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Header -------------------------------------------------
                const Text(
                  'Privacy Command Center',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: SortioColors.textBright,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Every setting is enforced on this device.',
                  style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                ),

                const SizedBox(height: 22),

                // -- Folder Sandbox ------------------------------------------
                Row(
                  children: [
                    const Expanded(child: SortioSectionLabel('Folder Sandbox')),
                    Flexible(
                      child: Text(
                        c.folderCount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SortioColors.accentSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: SortioColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SortioColors.borderCard),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < c.folders.length; i++) ...[
                        if (i > 0) const Divider(height: 1, thickness: 1, color: SortioColors.borderCard),
                        _FolderRow(folder: c.folders[i], controller: c),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // -- AI Strictness --------------------------------------------
                Row(
                  children: [
                    const Expanded(child: SortioSectionLabel('AI Strictness')),
                    Flexible(
                      child: Text(
                        strict.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SortioColors.accentSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    activeTrackColor: SortioColors.accent,
                    inactiveTrackColor: SortioColors.borderStrong,
                    thumbColor: SortioColors.accent,
                    overlayColor: SortioColors.accent.withValues(alpha: 0.28),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: c.strictness,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: c.setStrictness,
                  ),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Strict\n(95% match needed)',
                        style: TextStyle(fontSize: 11, height: 1.35, color: SortioColors.textMuted),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Creative\n(Guessing allowed)',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, height: 1.35, color: SortioColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: SortioColors.well,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SortioColors.border),
                  ),
                  child: Text(
                    strict.hint,
                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: SortioColors.textSoft),
                  ),
                ),

                const SizedBox(height: 22),

                // -- House Rules ----------------------------------------------
                const SortioSectionLabel('House Rules'),
                const SizedBox(height: 8),
                TextField(
                  controller: _rulesCtrl,
                  onChanged: c.setRules,
                  maxLines: 4,
                  minLines: 4,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: SortioColors.textBody,
                    fontFamily: SortioFonts.mono,
                  ),
                  cursorColor: SortioColors.accent,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Always file Zoom receipts under /Finance',
                    hintStyle: TextStyle(fontSize: 12.5, color: SortioColors.textMuted),
                    filled: true,
                    fillColor: SortioColors.well,
                    contentPadding: EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: SortioColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: SortioColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plain English. Read only by the on-device model.',
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),

                const SizedBox(height: 22),

                // -- Danger Zone ----------------------------------------------
                const SortioSectionLabel('Danger Zone'),
                const SizedBox(height: 8),
                PulseBox(
                  active: c.armed,
                  child: SortioPressScale(
                    onTap: c.onWipeTapped,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.armed ? SortioColors.redArm : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: c.armed ? SortioColors.redArm : SortioColors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: c.armed ? Colors.white : SortioColors.redSoft,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              c.armed ? 'Tap again to wipe everything' : 'Wipe AI Memory & Logs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.armed ? Colors.white : SortioColors.redSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deletes learned patterns, chat history and action logs. Your files stay untouched.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, height: 1.45, color: SortioColors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.controller});

  final FolderAccess folder;
  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SortioColors.card,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: const Icon(Icons.folder_outlined, size: 17, color: SortioColors.accentBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
                ),
                const SizedBox(height: 2),
                Text(
                  folder.path,
                  style: const TextStyle(
                    fontSize: 11,
                    color: SortioColors.textMuted,
                    fontFamily: SortioFonts.mono,
                  ),
                ),
              ],
            ),
          ),
          SortioSwitch(
            value: folder.allowed,
            onChanged: (_) => controller.toggleFolder(folder.key),
            width: 56,
            height: 44,
            trackWidth: 52,
            trackHeight: 32,
            thumbSize: 24,
          ),
        ],
      ),
    );
  }
}
