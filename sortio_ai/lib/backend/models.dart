// ============================================================================
// Sortio AI — backend/models.dart
//
// Data models: suggestions, chat messages, folder permissions, sessions and
// the savings summary. Pure data — no widgets, no state management.
// ============================================================================

import 'package:flutter/material.dart';

import 'design_tokens.dart';

enum SuggestionState { pending, applied, ignored }

/// Which visual accent a suggestion uses.
enum SuggestionTone { cyan, amber }

extension SuggestionToneX on SuggestionTone {
  Color get line => this == SuggestionTone.cyan ? SortioColors.accentBright : SortioColors.amber;
  Color get glow => this == SuggestionTone.cyan ? SortioColors.accent : SortioColors.amber;
}

/// One proposed tidy-up (a "card" in the chat feed).
class Suggestion {
  Suggestion({
    required this.id,
    required this.kind,
    required this.fromPath,
    required this.toPath,
    required this.tone,
    this.badge,
    this.extractLabel,
    this.extractValue,
    this.reason,
  });

  final String id; // 'bill' | 'exe'
  final String kind; // "Rename · Move · Extract" | "Quarantine"
  final String fromPath;
  String toPath;
  final SuggestionTone tone;
  final String? badge; // e.g. "Contains Account Number"
  final String? extractLabel; // e.g. "Total:"
  final String? extractValue; // e.g. "₱4,500"
  final String? reason; // e.g. "Unrecognized executable."

  SuggestionState state = SuggestionState.pending;
  bool closing = false;

  bool get isPending => state == SuggestionState.pending;

  /// Directory part / file-name part of the destination, like the prototype's
  /// `dir`/`name` split (the name is highlighted in cyan).
  (String dir, String name) get destinationParts {
    final cut = toPath.lastIndexOf('/') + 1;
    return (toPath.substring(0, cut), toPath.substring(cut));
  }

  /// Full destination: if the path ends with a slash it is a folder, so the
  /// file name is appended (quarantine case).
  String fullDestinationFor(String fileName) =>
      toPath.endsWith('/') ? toPath + fileName : toPath;

  void reset() {
    state = SuggestionState.pending;
    closing = false;
  }
}

/// A chat bubble beyond the scripted opening exchange.
class ChatMessage {
  const ChatMessage({required this.id, required this.isUser, required this.text});
  final String id;
  final bool isUser;
  final String text;
}

/// A folder the user can grant Sortio read access to.
class FolderAccess {
  const FolderAccess({required this.key, required this.label, required this.path, required this.allowed});
  final String key;
  final String label;
  final String path;
  final bool allowed;

  FolderAccess toggle() => FolderAccess(key: key, label: label, path: path, allowed: !allowed);
}

/// A session entry in the drawer.
class SessionEntry {
  const SessionEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.section,
  });
  final String id;
  final String title;
  final String subtitle;
  final SuggestionTone tone;
  final String section; // 'Current' | 'Recent'
}

/// The "Savings Summary" card output.
class SavingsSummary {
  const SavingsSummary({required this.files, required this.mbFreed, required this.minutesSaved});
  final int files;
  final int mbFreed;
  final int minutesSaved;
}
