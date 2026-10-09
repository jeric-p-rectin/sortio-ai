// ============================================================================
// Sortio AI — backend/data_output.dart
//
// The mock on-device "model" — the app's data output. Every string the agent
// produces and every dataset the UI renders comes from here, so swapping in a
// real on-device model later means touching only this class.
// ============================================================================

import 'models.dart';

abstract final class SortioData {
  static const String appName = 'Sortio AI';
  static const String onlineModelLine = 'On-device model ready';
  static const String offlineModelLine = 'Offline · on-device model active';
  static const String onlineFootLine = 'Private by design · files never leave this phone';
  static const String offlineFootLine = 'Offline · running 100% on this phone';

  /// The two scripted suggestions that open the session.
  static List<Suggestion> initialSuggestions() => [
        Suggestion(
          id: 'bill',
          kind: 'Rename · Move · Extract',
          fromPath: 'Downloads/IMG_2043.pdf',
          toPath: 'Documents/Invoices/2026-03_Meralco_Invoice.pdf',
          tone: SuggestionTone.cyan,
          badge: 'Contains Account Number',
          extractLabel: 'Total:',
          extractValue: '₱4,500',
        ),
        Suggestion(
          id: 'exe',
          kind: 'Quarantine',
          fromPath: 'Downloads/setup_v2.exe',
          toPath: 'Quarantine/holding_bin/',
          tone: SuggestionTone.amber,
          reason: 'Unrecognized executable.',
        ),
      ];

  static List<FolderAccess> folders({bool downloads = true, bool screenshots = true, bool documents = false}) => [
        FolderAccess(key: 'downloads', label: 'Downloads', path: '~/Downloads', allowed: downloads),
        FolderAccess(key: 'screenshots', label: 'Screenshots', path: '~/Pictures/Screenshots', allowed: screenshots),
        FolderAccess(key: 'documents', label: 'Documents', path: '~/Documents', allowed: documents),
      ];

  static List<SessionEntry> sessions() => const [
        SessionEntry(
          id: 'now',
          title: 'Meralco bill & downloads',
          subtitle: 'Active now',
          tone: SuggestionTone.cyan,
          section: 'Current',
        ),
        SessionEntry(
          id: 'tax',
          title: 'Tax Prep 2026',
          subtitle: 'Receipts & invoices',
          tone: SuggestionTone.cyan,
          section: 'Recent',
        ),
        SessionEntry(
          id: 'weekly',
          title: 'Weekly Downloads Tidy-up',
          subtitle: 'Repeats every Sunday',
          tone: SuggestionTone.cyan,
          section: 'Recent',
        ),
        SessionEntry(
          id: 'ids',
          title: 'ID Scans',
          subtitle: 'Sensitive · extra confirmation',
          tone: SuggestionTone.amber,
          section: 'Recent',
        ),
      ];

  static const SavingsSummary savings = SavingsSummary(files: 45, mbFreed: 200, minutesSaved: 15);

  /// "Downloads, Screenshots and Documents" — the join used in agent replies.
  static String joinNames(List<String> list) {
    if (list.length < 2) return list.join('');
    return '${list.sublist(0, list.length - 1).join(', ')} and ${list.last}';
  }

  /// The agent's reply to a user message, based on granted folders.
  static String agentReply(List<String> visibleFolderNames) => visibleFolderNames.isEmpty
      ? 'I cannot see any folders yet. Turn one on in the Privacy Command Center and I will take a look.'
      : 'On it. Scanning ${joinNames(visibleFolderNames)} on this device. '
          'I will show you every change before anything moves.';

  static const String emptyMessageHint = 'Try: "Find my March bank statement and file it."';

  /// Summary line shown once every suggestion has been resolved.
  static String doneLine(int appliedCount) {
    switch (appliedCount) {
      case 2:
        return 'All set: 2 tidy-ups applied on this device. Every move is logged, so you can undo anytime.';
      case 1:
        return 'Done: 1 tidy-up applied, 1 left as is. You can undo anytime.';
      default:
        return 'No changes made. Your files are exactly where they were.';
    }
  }

  /// Strictness slider output: threshold % + mode label + explainer.
  static ({String label, String hint, String mode, int threshold}) strictness(double value) {
    final v = value.clamp(0, 100);
    final thr = (95 - v * 0.35).round();
    final mode = v < 34 ? 'Strict' : v < 67 ? 'Balanced' : 'Creative';
    final hint = v < 34
        ? 'Acts only when it is at least $thr% sure. Anything less becomes a question for you.'
        : v < 67
            ? 'Suggests moves at $thr%+ confidence and flags anything it is unsure about.'
            : 'Guesses from context (down to $thr% confidence), but every guess still waits for your approval.';
    return (label: '$mode · $thr% match', hint: hint, mode: mode, threshold: thr);
  }
}
