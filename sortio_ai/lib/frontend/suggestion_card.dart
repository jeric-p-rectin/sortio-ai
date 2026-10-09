// ============================================================================
// Sortio AI — frontend/suggestion_card.dart
//
// The tidy-up suggestion card (approve / edit / ignore) with its paths box,
// sensitive-data badge, Magic Extract row, reasoning line and action buttons —
// plus the applied/ignored result row with Undo.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/models.dart';
import 'shared_widgets.dart';

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key, required this.suggestion, required this.controller});

  final Suggestion suggestion;
  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final c = controller;
    final isBill = s.extractValue != null;
    final editing = c.editingId == s.id;
    final (dir, name) = s.destinationParts;
    final index = c.suggestions.keys.toList().indexOf(s.id) + 1;
    final total = c.suggestions.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SortioColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SortioColors.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          // Kind + counter
          Row(
            children: [
              Icon(_kindIcon(s), size: 13, color: s.tone.line),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.kind.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.9,
                    color: SortioColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$index / $total',
                style: TextStyle(
                  fontSize: 11,
                  color: SortioColors.textMuted,
                  fontFamily: SortioFonts.mono,
                ),
              ),
            ],
          ),

          // Paths box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SortioColors.well,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SortioColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                _PathRow(label: 'From', value: s.fromPath),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PathLabel('To'),
                    if (!editing)
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: SortioColors.textSoft,
                              fontFamily: SortioFonts.mono,
                            ),
                            children: isBill
                                ? [
                                    TextSpan(text: dir),
                                    TextSpan(
                                      text: name,
                                      style: TextStyle(
                                        color: SortioColors.accentBright,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ]
                                : [
                                    TextSpan(
                                      text: s.toPath,
                                      style: TextStyle(
                                        color: SortioColors.accentBright,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: _EditPathField(
                          initialPath: c.draft,
                          onChanged: c.setDraft,
                          onSubmitted: () => c.saveEdit(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Sensitive badge (bill only)
          if (s.badge != null)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: SortioColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: SortioColors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: SortioColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    s.badge!,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SortioColors.amber),
                  ),
                ],
              ),
            ),

          // Magic Extract (bill only)
          if (s.extractValue != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: SortioColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: SortioColors.accent.withValues(alpha: 0.45),
                  // CSS uses a dashed border here.
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 12, color: SortioColors.accentSoft),
                            SizedBox(width: 5),
                            Text(
                              'MAGIC EXTRACT',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                                color: SortioColors.accentSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: s.extractLabel!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: SortioColors.textMuted,
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: s.extractValue!,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: SortioColors.textBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CopyButton(controller: c),
                ],
              ),
            ),

          // Reasoning (exe only)
          if (s.reason != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline, size: 16, color: SortioColors.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, height: 1.45, color: SortioColors.textSoft),
                      children: [
                        TextSpan(
                          text: 'Reasoning: ',
                          style: TextStyle(color: SortioColors.amber, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: s.reason),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Actions
          if (!editing)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ActionBtn(
                    label: 'Approve',
                    icon: Icons.check,
                    style: _BtnStyle.go,
                    onPressed: () => c.resolve(s.id, SuggestionState.applied),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _ActionBtn(
                    label: 'Edit',
                    style: _BtnStyle.line,
                    onPressed: () => c.startEdit(s.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _ActionBtn(
                    label: 'Ignore',
                    style: _BtnStyle.mute,
                    onPressed: () => c.resolve(s.id, SuggestionState.ignored),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ActionBtn(
                    label: 'Save path',
                    style: _BtnStyle.go,
                    onPressed: c.saveEdit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _ActionBtn(
                    label: 'Cancel',
                    style: _BtnStyle.line,
                    onPressed: c.cancelEdit,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _kindIcon(Suggestion s) =>
      s.tone == SuggestionTone.cyan ? Icons.auto_awesome : Icons.shield_outlined;
}

class _PathLabel extends StatelessWidget {
  const _PathLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    context.watchSortioTheme();
    return SizedBox(
      width: 34,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          height: 18 / 10,
          letterSpacing: 0.6,
          color: SortioColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PathLabel(label),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: SortioColors.textMuted,
              fontFamily: SortioFonts.mono,
            ),
          ),
        ),
      ],
    );
  }
}

/// The inline destination editor (`.edit-in`) — stateful so its
/// [TextEditingController] survives rebuilds while editing.
class _EditPathField extends StatefulWidget {
  const _EditPathField({required this.initialPath, required this.onChanged, required this.onSubmitted});

  final String initialPath;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<_EditPathField> createState() => _EditPathFieldState();
}

class _EditPathFieldState extends State<_EditPathField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialPath);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: true,
      style: TextStyle(
        fontSize: 12,
        color: SortioColors.textBody,
        fontFamily: SortioFonts.mono,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: SortioColors.page,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: SortioColors.accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: SortioColors.accent),
        ),
      ),
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmitted(),
      textInputAction: TextInputAction.done,
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.controller});

  final SortioController controller;

  @override
  Widget build(BuildContext context) {
    final copied = controller.copied;
    return Tooltip(
      message: copied ? 'Copied' : 'Copy total ₱4,500',
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: controller.copyExtract,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SortioColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: copied
                  ? SortioColors.green.withValues(alpha: 0.6)
                  : SortioColors.borderTile,
            ),
          ),
          child: Icon(
            copied ? Icons.check : Icons.copy_outlined,
            size: 18,
            color: copied ? SortioColors.greenBright : SortioColors.textSoft,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Applied / ignored result rows
// ---------------------------------------------------------------------------

class SortioDoneRow extends StatelessWidget {
  const SortioDoneRow.applied(this.s, this.c, {super.key}) : skipped = false;
  const SortioDoneRow.ignored(this.s, this.c, {super.key}) : skipped = true;

  final Suggestion s;
  final SortioController c;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final fileName = s.fromPath.split('/').last;
    final detail = skipped ? s.fromPath : '→ ${s.fullDestinationFor(fileName)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: skipped ? SortioColors.well : SortioColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: skipped ? SortioColors.borderStrong : SortioColors.green.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          if (!skipped) ...[
            Icon(Icons.check, size: 16, color: SortioColors.greenSoft),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skipped ? 'Ignored — file left untouched.' : 'Tidy-up applied.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: skipped ? SortioColors.textSoft : SortioColors.greenSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: SortioColors.textMuted,
                    fontFamily: SortioFonts.mono,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _UndoButton(controller: c, skipped: skipped, suggestionId: s.id),
        ],
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.controller, required this.skipped, required this.suggestionId});

  final SortioController controller;
  final bool skipped;
  final String suggestionId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => controller.undo(suggestionId),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: skipped ? SortioColors.borderStrong : SortioColors.greenSoft.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.undo,
              size: 14,
              color: skipped ? SortioColors.textSoft : SortioColors.greenFaint,
            ),
            const SizedBox(width: 6),
            Text(
              'Undo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: skipped ? SortioColors.textSoft : SortioColors.greenFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons (Approve / Edit / Ignore / Save path / Cancel)
// ---------------------------------------------------------------------------

enum _BtnStyle { go, line, mute }

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.style, required this.onPressed, this.icon});

  final String label;
  final _BtnStyle style;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      _BtnStyle.go => (SortioColors.accent, SortioColors.onAccent, BorderSide.none),
      _BtnStyle.line => (Colors.transparent, SortioColors.textBody, BorderSide(color: SortioColors.borderStrong)),
      _BtnStyle.mute => (SortioColors.borderStrong, SortioColors.textSoft, BorderSide.none),
    };
    final btn = Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: border == BorderSide.none ? null : Border.fromBorderSide(border),
        boxShadow: style == _BtnStyle.go
            ? [
                BoxShadow(
                  color: SortioColors.accent.withValues(alpha: 0.75),
                  offset: const Offset(0, 8),
                  blurRadius: 22,
                  spreadRadius: -8,
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
    return SortioPressScale(onTap: onPressed, child: btn);
  }
}
