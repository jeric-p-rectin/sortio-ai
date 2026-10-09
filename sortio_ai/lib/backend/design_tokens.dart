// ============================================================================
// Sortio AI — backend/design_tokens.dart
//
// Design tokens lifted 1:1 from the prototype's CSS: the color palette and
// the bundled font families. Every screen reads its look from here.
//
// Colors come in two palettes — dark (the original look) and light — and the
// active one is swapped by the Dark mode setting. Screens read the plain
// static getters, so a theme switch needs no per-widget wiring: the theme bus
// (SortioThemeBus) notifies the app root, which rebuilds the whole tree.
// ============================================================================

import 'package:flutter/material.dart';

/// One complete set of design tokens — a dark or a light look.
class SortioPalette {
  const SortioPalette({
    required this.page,
    required this.panel,
    required this.card,
    required this.well,
    required this.chipBg,
    required this.toastBg,
    required this.hover,
    required this.border,
    required this.borderCard,
    required this.borderTile,
    required this.borderStrong,
    required this.borderSession,
    required this.textBright,
    required this.textBody,
    required this.textSoft,
    required this.textMuted,
    required this.accent,
    required this.accentBright,
    required this.accentSoft,
    required this.onAccent,
    required this.green,
    required this.greenBright,
    required this.greenSoft,
    required this.greenFaint,
    required this.amber,
    required this.red,
    required this.redSoft,
    required this.redArm,
    required this.scrim,
  });

  // Backgrounds
  final Color page;
  final Color panel;
  final Color card;
  final Color well; // inputs / path boxes
  final Color chipBg;
  final Color toastBg;
  final Color hover;

  // Borders
  final Color border;
  final Color borderCard;
  final Color borderTile;
  final Color borderStrong;
  final Color borderSession;

  // Text
  final Color textBright;
  final Color textBody;
  final Color textSoft;
  final Color textMuted;

  // Cyan accent
  final Color accent;
  final Color accentBright;
  final Color accentSoft;
  final Color onAccent;

  // Green (success / user bubbles)
  final Color green;
  final Color greenBright;
  final Color greenSoft;
  final Color greenFaint;

  // Amber (warnings / sensitive)
  final Color amber;

  // Red (danger zone)
  final Color red;
  final Color redSoft;
  final Color redArm;

  // Scrim
  final Color scrim;
}

/// The original look — cyan-on-slate dark.
const SortioPalette _darkPalette = SortioPalette(
  page: Color(0xFF0B0F19),
  panel: Color(0xFF0E1424),
  card: Color(0xFF1A233A),
  well: Color(0xFF111827), // inputs / path boxes
  chipBg: Color(0xFF0F1524),
  toastBg: Color(0xFF0F1A2E),
  hover: Color(0xFF151D31),
  border: Color(0xFF1E293B),
  borderCard: Color(0xFF243049),
  borderTile: Color(0xFF273352),
  borderStrong: Color(0xFF334155),
  borderSession: Color(0xFF2B3958),
  textBright: Color(0xFFF8FAFC),
  textBody: Color(0xFFE2E8F0),
  textSoft: Color(0xFFCBD5E1),
  textMuted: Color(0xFF94A3B8),
  accent: Color(0xFF06B6D4),
  accentBright: Color(0xFF22D3EE),
  accentSoft: Color(0xFF67E8F9),
  onAccent: Color(0xFF04131A),
  green: Color(0xFF10B981),
  greenBright: Color(0xFF34D399),
  greenSoft: Color(0xFF6EE7B7),
  greenFaint: Color(0xFFA7F3D0),
  amber: Color(0xFFF59E0B),
  red: Color(0xFFEF4444),
  redSoft: Color(0xFFF87171),
  redArm: Color(0xFFDC2626),
  scrim: Color(0x9E02060F), // rgba(2,6,15,.62)
);

/// The light look — the same layout on paper-white, with the accent
/// deepened so text and icons keep their contrast.
const SortioPalette _lightPalette = SortioPalette(
  page: Color(0xFFF4F6FB),
  panel: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  well: Color(0xFFEEF2F8),
  chipBg: Color(0xFFEDF1F7),
  toastBg: Color(0xFFFFFFFF),
  hover: Color(0xFFE7ECF5),
  border: Color(0xFFDFE6F0),
  borderCard: Color(0xFFE2E8F0),
  borderTile: Color(0xFFD7DFEA),
  borderStrong: Color(0xFFC3CDDB),
  borderSession: Color(0xFFC3CDDB),
  textBright: Color(0xFF0B1220),
  textBody: Color(0xFF1E293B),
  textSoft: Color(0xFF334155),
  textMuted: Color(0xFF64748B),
  accent: Color(0xFF0891B2),
  accentBright: Color(0xFF0E7490),
  accentSoft: Color(0xFF0E7490),
  onAccent: Color(0xFFFFFFFF),
  green: Color(0xFF10B981),
  greenBright: Color(0xFF059669),
  greenSoft: Color(0xFF047857),
  greenFaint: Color(0xFF065F46),
  amber: Color(0xFFD97706),
  red: Color(0xFFDC2626),
  redSoft: Color(0xFFB91C1C),
  redArm: Color(0xFFB91C1C),
  scrim: Color(0x6602060F), // rgba(2,6,15,.4)
);

/// Registers the calling widget as a dependent of the app theme.
///
/// The Sortio colors are plain static getters, so a widget that is created
/// with `const` is never rebuilt when the palette changes and would keep its
/// old (e.g. dark-mode) colors. Calling [watchSortioTheme] at the top of such
/// a widget's `build` makes Flutter rebuild it on every Dark mode switch.
extension SortioThemeContext on BuildContext {
  void watchSortioTheme() {
    Theme.of(this);
  }
}

/// Typography families — declared in pubspec.yaml (bundled, fully offline).
abstract final class SortioFonts {
  static const String sans = 'Sora';
  static const String mono = 'JetBrainsMono';
}

/// Colors lifted 1:1 from the prototype's CSS. The getters resolve against the
/// active palette; the Dark mode setting swaps it app-wide.
abstract final class SortioColors {
  static SortioPalette _palette = _darkPalette;

  /// The active palette (dark by default).
  static SortioPalette get palette => _palette;

  static bool get isDark => identical(_palette, _darkPalette);

  /// Swaps the active palette. Callers rebuild the tree afterwards — the
  /// [SortioThemeBus] handles that.
  static void setDark(bool dark) => _palette = dark ? _darkPalette : _lightPalette;

  // Backgrounds
  static Color get page => _palette.page;
  static Color get panel => _palette.panel;
  static Color get card => _palette.card;
  static Color get well => _palette.well; // inputs / path boxes
  static Color get chipBg => _palette.chipBg;
  static Color get toastBg => _palette.toastBg;
  static Color get hover => _palette.hover;

  // Borders
  static Color get border => _palette.border;
  static Color get borderCard => _palette.borderCard;
  static Color get borderTile => _palette.borderTile;
  static Color get borderStrong => _palette.borderStrong;
  static Color get borderSession => _palette.borderSession;

  // Text
  static Color get textBright => _palette.textBright;
  static Color get textBody => _palette.textBody;
  static Color get textSoft => _palette.textSoft;
  static Color get textMuted => _palette.textMuted;

  // Cyan accent
  static Color get accent => _palette.accent;
  static Color get accentBright => _palette.accentBright;
  static Color get accentSoft => _palette.accentSoft;
  static Color get onAccent => _palette.onAccent;

  // Green (success / user bubbles)
  static Color get green => _palette.green;
  static Color get greenBright => _palette.greenBright;
  static Color get greenSoft => _palette.greenSoft;
  static Color get greenFaint => _palette.greenFaint;

  // Amber (warnings / sensitive)
  static Color get amber => _palette.amber;

  // Red (danger zone)
  static Color get red => _palette.red;
  static Color get redSoft => _palette.redSoft;
  static Color get redArm => _palette.redArm;

  // Scrim
  static Color get scrim => _palette.scrim;
}

/// The theme bus: whoever changes the palette notifies this, and the app root
/// (which listens here) rebuilds the whole tree with the new colors.
class SortioThemeBus extends ChangeNotifier {
  SortioThemeBus._();

  static final SortioThemeBus instance = SortioThemeBus._();

  /// True while the dark palette is active.
  bool get isDark => SortioColors.isDark;

  /// Swaps the palette and repaints the app.
  void setDark(bool dark) {
    if (SortioColors.isDark == dark) return;
    SortioColors.setDark(dark);
    notifyListeners();
  }
}
