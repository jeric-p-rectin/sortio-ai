import 'package:path/path.dart' as p;

/// What the rules decided about a file.
class RuleMatch {
  final String category;
  final String reason;
  final double confidence;

  /// True when the file looks like a scan with a meaningless name
  /// (IMG_2043.pdf). These are candidates for AI rename.
  final bool needsRename;

  /// True when the file should go to the quarantine folder instead of a
  /// category folder (e.g. a Windows executable on a phone).
  final bool quarantine;

  const RuleMatch({
    required this.category,
    required this.reason,
    required this.confidence,
    this.needsRename = false,
    this.quarantine = false,
  });
}

/// Deterministic, no-AI classification by file name and extension.
/// This handles most of the sorting so the LLM is only needed for renames
/// and search.
class RulesEngine {
  static const _byExtension = <String, (String, String)>{
    // ext: (category, label)
    'pdf': ('Documents', 'PDF document'),
    'doc': ('Documents', 'Word document'),
    'docx': ('Documents', 'Word document'),
    'odt': ('Documents', 'Text document'),
    'rtf': ('Documents', 'Text document'),
    'txt': ('Documents', 'Text file'),
    'xls': ('Documents', 'Spreadsheet'),
    'xlsx': ('Documents', 'Spreadsheet'),
    'csv': ('Documents', 'Spreadsheet'),
    'ppt': ('Documents', 'Presentation'),
    'pptx': ('Documents', 'Presentation'),
    'jpg': ('Images', 'Image'),
    'jpeg': ('Images', 'Image'),
    'png': ('Images', 'Image'),
    'gif': ('Images', 'Image'),
    'webp': ('Images', 'Image'),
    'heic': ('Images', 'Image'),
    'bmp': ('Images', 'Image'),
    'mp4': ('Videos', 'Video'),
    'mkv': ('Videos', 'Video'),
    'mov': ('Videos', 'Video'),
    'avi': ('Videos', 'Video'),
    'webm': ('Videos', 'Video'),
    '3gp': ('Videos', 'Video'),
    'mp3': ('Audio', 'Audio file'),
    'wav': ('Audio', 'Audio file'),
    'm4a': ('Audio', 'Audio file'),
    'aac': ('Audio', 'Audio file'),
    'ogg': ('Audio', 'Audio file'),
    'opus': ('Audio', 'Voice note / audio'),
    'flac': ('Audio', 'Audio file'),
    'zip': ('Archives', 'Compressed archive'),
    'rar': ('Archives', 'Compressed archive'),
    '7z': ('Archives', 'Compressed archive'),
    'tar': ('Archives', 'Compressed archive'),
    'gz': ('Archives', 'Compressed archive'),
    'apk': ('Installers', 'Android installer'),
  };

  /// Executables and scripts that cannot run on a phone and are a common
  /// malware carrier. Suggested for quarantine (never deleted).
  static const _quarantineExtensions = {
    'exe', 'msi', 'bat', 'cmd', 'com', 'scr', 'vbs', 'js', 'jar', 'ps1', 'dll',
  };

  /// Folder name used for quarantine suggestions.
  static const quarantineCategory = 'Sortio Quarantine';

  static const _scannable = {'pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp'};

  static final _screenshot = RegExp(r'^screenshot', caseSensitive: false);
  static final _scanWord = RegExp(r'scan', caseSensitive: false);

  /// Camera/scanner default names like IMG_2043, DOC_0012, 20260301_101500.
  static final _genericName = RegExp(
    r'^(img|image|doc|document|pxl|dsc)[ _-]?\d|^\d{8}[ _-]?\d{0,6}$',
    caseSensitive: false,
  );

  /// Files we never touch: hidden files and unfinished downloads.
  static bool isIgnored(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.startsWith('.') ||
        lower.endsWith('.crdownload') ||
        lower.endsWith('.part') ||
        lower.endsWith('.partial') ||
        lower.endsWith('.tmp') ||
        lower.endsWith('.download');
  }

  RuleMatch? classify(String fileName) {
    if (isIgnored(fileName)) return null;
    final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final stem = p.basenameWithoutExtension(fileName);
    final known = _byExtension[ext];

    if (_quarantineExtensions.contains(ext)) {
      return const RuleMatch(
        category: quarantineCategory,
        reason: 'Unrecognized executable. Held in quarantine, not deleted.',
        confidence: 0.9,
        quarantine: true,
      );
    }

    if (_screenshot.hasMatch(stem) && known?.$1 == 'Images') {
      return const RuleMatch(
        category: 'Screenshots',
        reason: 'Screenshot → Screenshots',
        confidence: 0.95,
      );
    }

    // A PDF with a camera-style name, or anything called "scan…", is almost
    // certainly a scanned document. Plain IMG_1234.jpg is usually a photo.
    final looksScanned = _scanWord.hasMatch(stem) ||
        (ext == 'pdf' && _genericName.hasMatch(stem));
    if (_scannable.contains(ext) && looksScanned) {
      return const RuleMatch(
        category: 'Scans',
        reason: 'Looks like a scanned document with a generic name → Scans',
        confidence: 0.7,
        needsRename: true,
      );
    }

    if (known == null) return null;
    final (category, label) = known;
    return RuleMatch(
      category: category,
      reason: '$label → $category',
      confidence: 0.95,
    );
  }
}
