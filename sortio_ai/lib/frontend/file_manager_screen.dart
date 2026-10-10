// ============================================================================
// Sortio AI — frontend/file_manager_screen.dart
//
// Screen: File Manager — the folders Sortio can see (driven by the shared
// controller's sandbox settings) and the files inside them, with suggested
// and sensitive badges. Locked folders show a friendly placeholder.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/data_output.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import '../backend/navigation.dart';
import 'shared_widgets.dart';

class FileManagerScreen extends StatelessWidget {
  const FileManagerScreen({super.key, required this.controller, required this.navigation});

  final SortioController controller;
  final SortioNavigationController navigation;

  @override
  Widget build(BuildContext context) {
    final allFiles = SortioData.files();
    final sandbox = controller.folders;

    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Header ----------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Files',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: SortioColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      controller.folderCount,
                      style: TextStyle(fontSize: 12, color: SortioColors.textMuted),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // -- Folder list ------------------------------------------------
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    for (final folder in sandbox) ...[
                      _FolderSection(
                        label: folder.label,
                        path: folder.path,
                        allowed: folder.allowed,
                        files: allFiles.where((f) => f.folderKey == folder.key).toList(),
                        onEnable: () => controller.toggleFolder(folder.key),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Quarantine is Sortio's own holding area — always visible.
                    _FolderSection(
                      label: 'Quarantine',
                      path: 'Quarantine/holding_bin/',
                      allowed: true,
                      files: allFiles.where((f) => f.folderKey == 'quarantine').toList(),
                      onEnable: () {},
                      system: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({
    required this.label,
    required this.path,
    required this.allowed,
    required this.files,
    required this.onEnable,
    this.system = false,
  });

  final String label;
  final String path;
  final bool allowed;
  final List<FileItem> files;
  final VoidCallback onEnable;
  final bool system;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SortioColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortioColors.borderCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Folder header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  child: Icon(
                    allowed ? Icons.folder_outlined : Icons.lock_outline,
                    size: 17,
                    color: allowed ? SortioColors.accentBright : SortioColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SortioColors.textBright,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        path,
                        style: TextStyle(
                          fontSize: 11,
                          color: SortioColors.textMuted,
                          fontFamily: SortioFonts.mono,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  allowed ? '${files.length} files' : 'Locked',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: allowed ? SortioColors.accentSoft : SortioColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Content
          if (!allowed && !system)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SortioPressScale(
                onTap: onEnable,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: SortioColors.well,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SortioColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 15, color: SortioColors.accentSoft),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Allow Sortio to see this folder in Settings',
                          style: TextStyle(fontSize: 12, color: SortioColors.textSoft),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: SortioColors.textMuted),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < files.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: SortioColors.borderCard),
                  _FileRow(item: files[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.item});

  final FileItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (item.kind) {
      FileKind.pdf => (Icons.picture_as_pdf_outlined, SortioColors.redSoft),
      FileKind.exe => (Icons.warning_amber_rounded, SortioColors.amber),
      FileKind.image => (Icons.image_outlined, SortioColors.accentBright),
      FileKind.doc => (Icons.article_outlined, SortioColors.textSoft),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SortioColors.borderTile),
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SortioColors.textBright,
                          fontFamily: SortioFonts.mono,
                        ),
                      ),
                    ),
                    if (item.suggested) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: SortioColors.accent.withValues(alpha: 0.14),
                          border: Border.all(color: SortioColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Suggested',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SortioColors.accentSoft),
                        ),
                      ),
                    ],
                    if (item.sensitive) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.warning_amber_rounded, size: 13, color: SortioColors.amber),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.size} · ${item.modified}',
                  style: TextStyle(fontSize: 11, color: SortioColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
