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

  /// The scripted demo conversation — its suggestion cards live in the feed.
  static const String scriptedChatId = 'demo';

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

  static List<FolderAccess> folders({bool downloads = true, bool photos = true, bool documents = false}) => [
        FolderAccess(key: 'downloads', label: 'Downloads', path: '~/Downloads', allowed: downloads),
        FolderAccess(key: 'photos', label: 'Photos', path: '~/DCIM/Camera · ~/Pictures', allowed: photos),
        FolderAccess(key: 'documents', label: 'Documents', path: '~/Documents', allowed: documents),
      ];

  static const SavingsSummary savings = SavingsSummary(files: 45, mbFreed: 200, minutesSaved: 15);

  /// The chat history shown in the History (chats) screen, newest first. The
  /// scripted demo conversation is seeded first; every chat the user starts is
  /// inserted at the top of this list by the controller.
  /// Live chats published by the controller once the on-device engine runs
  /// (persisted in SQLite); null means "use the demo chats".
  static List<ChatSession>? liveChats;

  static List<ChatSession> chatSessions() => liveChats ?? demoChatSessions();

  /// First-launch chat: Sortio introduces itself and reports its first scan.
  static const String welcomeTitle = 'Your first tidy-up';
  static const String welcomeLine =
      'Hi! I am Sortio. I only look at the folders you allow, everything stays '
      'on this phone, and nothing moves until you approve.';

  /// Marks a suggestion the AI is not sure enough about for the strictness
  /// setting: it stays a question for the user instead of a recommendation.
  static String lowConfidenceReason(int percent, int threshold) =>
      'Only $percent% sure (your setting asks for $threshold%). Check it before approving.';

  /// Prefix the engine uses for suggestions made by a house rule.
  static const String houseRulePrefix = 'Your rule:';

  static String rulesApplied(int count) => count == 0
      ? 'No house rules recognised yet. Try "Always file Zoom receipts under Finance".'
      : '$count house rule${count == 1 ? '' : 's'} active. Re-checking your folders.';

  static List<ChatSession> demoChatSessions() {
    final now = DateTime.now();
    return [
      ChatSession(
        id: scriptedChatId,
        title: 'Meralco bill & downloads',
        updatedAt: now.subtract(const Duration(hours: 2)),
        messages: const [
          ChatMessage(
            id: 'm1',
            isUser: true,
            text: 'Find my Meralco bill from March and tidy my recent downloads.',
          ),
          ChatMessage(
            id: 'm2',
            isUser: false,
            text: 'Found your bill and 2 other files. Here are my suggestions:',
          ),
        ],
      ),
      ChatSession(
        id: 'ch-receipts',
        title: 'March receipts for taxes',
        updatedAt: now.subtract(const Duration(hours: 5)),
        messages: const [
          ChatMessage(id: 'm1', isUser: true, text: 'Find every receipt from March for my taxes.'),
          ChatMessage(
            id: 'm2',
            isUser: false,
            text: 'Found 4 receipts in Downloads and Screenshots, from March 2 to March 28. '
                'Want me to copy them into Documents/Receipts/2026-03/?',
          ),
          ChatMessage(id: 'm3', isUser: true, text: 'Yes, copy all of them there.'),
          ChatMessage(
            id: 'm4',
            isUser: false,
            text: 'Done: 4 receipts copied. Nothing was moved, so the originals are untouched.',
          ),
        ],
      ),
      ChatSession(
        id: 'ch-weekly',
        title: 'Weekly Downloads tidy-up',
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
        messages: const [
          ChatMessage(id: 'm1', isUser: true, text: 'Tidy my Downloads folder.'),
          ChatMessage(
            id: 'm2',
            isUser: false,
            text: 'Planned 12 moves and 3 renames — every one reversible. '
                'Approve what you like; nothing moves until you do.',
          ),
        ],
      ),
      ChatSession(
        id: 'ch-passport',
        title: 'Where is my passport scan?',
        updatedAt: now.subtract(const Duration(days: 3)),
        messages: const [
          ChatMessage(id: 'm1', isUser: true, text: 'Where did I put my passport scan?'),
          ChatMessage(
            id: 'm2',
            isUser: false,
            text: 'It is in Documents/IDs/Passport_2025.pdf, filed there on Feb 28 '
                'with extra confirmation because it is a sensitive ID.',
          ),
        ],
      ),
    ];
  }

  /// Live file list published by the controller once the on-device engine
  /// runs; null means "use the demo data" (widget tests, web, no engine).
  static List<FileItem>? liveFiles;

  /// Files shown in the File Manager screen, grouped by folder key.
  static List<FileItem> files() => liveFiles ?? demoFiles();


  static List<FileItem> demoFiles() => const [
        FileItem(
          folderKey: 'downloads',
          name: 'IMG_2043.pdf',
          size: '1.2 MB',
          modified: 'Mar 3',
          kind: FileKind.pdf,
          suggested: true,
        ),
        FileItem(
          folderKey: 'downloads',
          name: 'setup_v2.exe',
          size: '84 MB',
          modified: 'Mar 3',
          kind: FileKind.exe,
          suggested: true,
        ),
        FileItem(
          folderKey: 'downloads',
          name: 'march_receipt.jpg',
          size: '340 KB',
          modified: 'Mar 2',
          kind: FileKind.image,
        ),
        FileItem(
          folderKey: 'downloads',
          name: 'meeting_notes.docx',
          size: '56 KB',
          modified: 'Mar 1',
          kind: FileKind.doc,
        ),
        FileItem(
          folderKey: 'documents',
          name: '2026-03_Meralco_Invoice.pdf',
          size: '1.2 MB',
          modified: 'Mar 3',
          kind: FileKind.pdf,
        ),
        FileItem(
          folderKey: 'documents',
          name: 'PhilID_2026.jpg',
          size: '2.1 MB',
          modified: 'Feb 28',
          kind: FileKind.image,
          sensitive: true,
        ),
        FileItem(
          folderKey: 'screenshots',
          name: 'Screenshot_2026-03-01.png',
          size: '280 KB',
          modified: 'Mar 1',
          kind: FileKind.image,
        ),
        FileItem(
          folderKey: 'screenshots',
          name: 'Screenshot_2026-02-27.png',
          size: '310 KB',
          modified: 'Feb 27',
          kind: FileKind.image,
        ),
        FileItem(
          folderKey: 'quarantine',
          name: 'setup_v2.exe',
          size: '84 MB',
          modified: 'Mar 3',
          kind: FileKind.exe,
        ),
        FileItem(
          folderKey: 'quarantine',
          name: 'unknown_installer.apk',
          size: '12 MB',
          modified: 'Feb 25',
          kind: FileKind.exe,
        ),
      ];

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

  /// Shared storage root on Android and where each sandbox folder lives in it.
  static const String storageRoot = '/storage/emulated/0';
  static const Map<String, List<String>> folderDirs = {
    'downloads': ['Download'],
    // Camera roll, saved pictures and screenshots. Only photos of documents
    // are ever suggested from here (see LocalSortioCore.photoRoots).
    'photos': ['DCIM/Camera', 'Pictures', 'Pictures/Screenshots'],
    'documents': ['Documents'],
  };

  /// Folder keys whose files follow the photo policy.
  static const Set<String> photoFolderKeys = {'photos'};

  /// Summary line shown once every suggestion has been resolved.
  static String doneLine(int appliedCount, [int total = 2]) {
    if (total == 0) {
      return 'Your allowed folders are already tidy. Nothing to change.';
    }
    final left = total - appliedCount;
    if (appliedCount == 0) {
      return 'No changes made. Your files are exactly where they were.';
    }
    final applied = appliedCount == 1 ? '1 tidy-up' : '$appliedCount tidy-ups';
    if (left == 0) {
      return 'All set: $applied applied on this device. Every move is logged, so you can undo anytime.';
    }
    return 'Done: $applied applied, $left left as is. You can undo anytime.';
  }

  static const String scanningLine = 'Scanning your allowed folders on this device…';
  static const String permissionHint =
      'Allow "All files access" for Sortio in Settings so it can tidy your folders. Nothing is uploaded.';

  /// Reply to a tidy request after a fresh scan.
  static String scanReply(int count, List<String> folderNames) => count == 0
      ? 'I checked ${joinNames(folderNames)}. Everything is already tidy.'
      : 'I checked ${joinNames(folderNames)} and found $count file${count == 1 ? '' : 's'} to tidy. Nothing moves until you approve:';

  /// Reply to a search request.
  static String searchReply(String query, List<({String name, String where, String why})> hits) {
    if (hits.isEmpty) {
      return 'I could not find anything matching "$query" in your allowed folders.';
    }
    final lines = hits.take(5).map((h) => '• ${h.name}\n   in ${h.where} (${h.why})').join('\n');
    final more = hits.length > 5 ? '\n…and ${hits.length - 5} more.' : '';
    return 'Found ${hits.length} file${hits.length == 1 ? '' : 's'}:\n$lines$more';
  }
}
