// ============================================================================
// Sortio AI — backend/design_tokens.dart
//
// Design tokens lifted 1:1 from the prototype's CSS: the color palette and
// the bundled font families. Every screen reads its look from here.
// ============================================================================

import 'package:flutter/material.dart';

/// Colors lifted 1:1 from the prototype's CSS.
abstract final class SortioColors {
  // Backgrounds
  static const Color page = Color(0xFF0B0F19);
  static const Color panel = Color(0xFF0E1424);
  static const Color card = Color(0xFF1A233A);
  static const Color well = Color(0xFF111827); // inputs / path boxes
  static const Color chipBg = Color(0xFF0F1524);
  static const Color toastBg = Color(0xFF0F1A2E);
  static const Color hover = Color(0xFF151D31);

  // Borders
  static const Color border = Color(0xFF1E293B);
  static const Color borderCard = Color(0xFF243049);
  static const Color borderTile = Color(0xFF273352);
  static const Color borderStrong = Color(0xFF334155);
  static const Color borderSession = Color(0xFF2B3958);

  // Text
  static const Color textBright = Color(0xFFF8FAFC);
  static const Color textBody = Color(0xFFE2E8F0);
  static const Color textSoft = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  // Cyan accent
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentBright = Color(0xFF22D3EE);
  static const Color accentSoft = Color(0xFF67E8F9);
  static const Color onAccent = Color(0xFF04131A);

  // Green (success / user bubbles)
  static const Color green = Color(0xFF10B981);
  static const Color greenBright = Color(0xFF34D399);
  static const Color greenSoft = Color(0xFF6EE7B7);
  static const Color greenFaint = Color(0xFFA7F3D0);

  // Amber (warnings / sensitive)
  static const Color amber = Color(0xFFF59E0B);

  // Red (danger zone)
  static const Color red = Color(0xFFEF4444);
  static const Color redSoft = Color(0xFFF87171);
  static const Color redArm = Color(0xFFDC2626);

  // Scrim
  static const Color scrim = Color(0x9E02060F); // rgba(2,6,15,.62)
}

/// Typography families — declared in pubspec.yaml (bundled, fully offline).
abstract final class SortioFonts {
  static const String sans = 'Sora';
  static const String mono = 'JetBrainsMono';
}
