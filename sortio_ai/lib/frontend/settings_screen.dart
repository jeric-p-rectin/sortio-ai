// ============================================================================
// Sortio AI — frontend/settings_screen.dart
//
// Screen: Settings — folder sandbox, appearance (dark mode) and the danger
// zone (memory wipe). Shares the app-wide SortioController so these settings
// drive the chat.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/animations.dart';
import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import 'shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
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
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: SortioColors.textBright,
                  ),
                ),
                // Blank subtitle line keeps the original spacing rhythm.
                const SizedBox(height: 17),

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
                        style: TextStyle(
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
                        if (i > 0) Divider(height: 1, thickness: 1, color: SortioColors.borderCard),
                        _FolderRow(folder: c.folders[i], controller: c),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // -- Appearance -----------------------------------------------
                const SortioSectionLabel('Appearance'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: SortioColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SortioColors.borderCard),
                  ),
                  child: Column(
                    children: [
                      _SettingToggleRow(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark mode',
                        subtitle: c.darkMode ? 'The slate-and-cyan look' : 'The paper-white look',
                        value: c.darkMode,
                        enabled: true,
                        onChanged: c.setDarkMode,
                        switchKey: const ValueKey('dark-mode-switch'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The theme applies instantly, everywhere in the app.',
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
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One settings row: icon tile, title + subtitle, and a switch.
class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.switchKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final Key? switchKey;

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
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: Icon(icon, size: 17, color: SortioColors.accentBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled ? SortioColors.textBright : SortioColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
            ),
          ),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: SortioSwitch(
                key: switchKey,
                value: value,
                onChanged: onChanged,
                width: 56,
                height: 44,
                trackWidth: 52,
                trackHeight: 32,
                thumbSize: 24,
              ),
            ),
          ),
        ],
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
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: Icon(Icons.folder_outlined, size: 17, color: SortioColors.accentBright),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SortioColors.textBright),
                ),
                const SizedBox(height: 2),
                Text(
                  folder.path,
                  style: TextStyle(
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
