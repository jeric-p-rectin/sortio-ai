// ============================================================================
// Sortio AI — backend/motion.dart
//
// The motion spec: every duration and curve the UI animates with, mirroring
// the prototype's CSS transitions and keyframes
// (pop / blink / pulse / collapse / drawer / sheet / toast).
// ============================================================================

import 'package:flutter/material.dart';

abstract final class SortioMotion {
  // Durations
  static const Duration pop = Duration(milliseconds: 350); // @keyframes pop
  static const Duration fade = Duration(milliseconds: 280);
  static const Duration collapse = Duration(milliseconds: 400); // card collapse
  static const Duration resolveDelay = Duration(milliseconds: 380);
  static const Duration drawer = Duration(milliseconds: 400);
  static const Duration sheet = Duration(milliseconds: 450);
  static const Duration scrim = Duration(milliseconds: 300);
  static const Duration toast = Duration(milliseconds: 320);
  static const Duration typingCycle = Duration(milliseconds: 1100); // blink
  static const Duration pulse = Duration(milliseconds: 1000); // armed pulse

  // Behavioural delays (from the controller logic)
  static const Duration agentThinking = Duration(milliseconds: 1300);
  static const Duration toastHold = Duration(milliseconds: 3000);
  static const Duration copiedHold = Duration(milliseconds: 2000);
  static const Duration armHold = Duration(milliseconds: 3500);
  static const Duration scrollSettle = Duration(milliseconds: 60);

  // Curves — cubic-bezier(.2,.8,.2,1) ≙ easeOutCubic,
  //           cubic-bezier(.4,0,.2,1) ≙ easeInOut
  static const Curve slideIn = Curves.easeOutCubic;
  static const Curve collapseCurve = Curves.easeInOut;
}
