import 'package:path/path.dart' as p;

/// The only three actions Sortio is ever allowed to perform.
enum ActionType { move, rename, createFolder }

/// A proposed change shown on the approval screen. Nothing happens until the
/// user approves it and it is passed to `SortioCore.apply`.
class Suggestion {
  final String id;
  final ActionType type;
  final String sourcePath;
  final String targetPath;

  /// Short human-readable reason, e.g. "PDF document → Documents".
  final String reason;

  /// 0.0–1.0. Rules are ~0.9+, AI suggestions report their own.
  final double confidence;

  /// Category folder name, e.g. "Documents". Null for plain renames.
  final String? category;

  /// The file has a meaningless name (IMG_2043.pdf) and is a candidate for
  /// AI rename from its content.
  final bool needsRename;

  /// True when the target name came from the AI rename pipeline.
  final bool aiNamed;

  /// A recent photo that may be a document. The UI should not show it until
  /// OCR confirms it has document text (see `LocalSortioCore.photoRoots`).
  final bool needsDocumentCheck;

  const Suggestion({
    required this.id,
    required this.type,
    required this.sourcePath,
    required this.targetPath,
    required this.reason,
    this.confidence = 1.0,
    this.category,
    this.needsRename = false,
    this.aiNamed = false,
    this.needsDocumentCheck = false,
  });

  String get fileName => p.basename(sourcePath);
  String get targetName => p.basename(targetPath);

  /// Lets the UI edit the proposed name/destination before approving.
  Suggestion copyWith({
    String? targetPath,
    String? reason,
    double? confidence,
    bool? needsRename,
    bool? needsDocumentCheck,
  }) =>
      Suggestion(
        id: id,
        type: type,
        sourcePath: sourcePath,
        targetPath: targetPath ?? this.targetPath,
        reason: reason ?? this.reason,
        confidence: confidence ?? this.confidence,
        category: category,
        needsRename: needsRename ?? this.needsRename,
        aiNamed: aiNamed,
        needsDocumentCheck: needsDocumentCheck ?? this.needsDocumentCheck,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'reason': reason,
        'confidence': confidence,
        'category': category,
        'needsRename': needsRename,
        'aiNamed': aiNamed,
        'needsDocumentCheck': needsDocumentCheck,
      };

  @override
  String toString() => 'Suggestion(${type.name}: $fileName → $targetPath)';
}
