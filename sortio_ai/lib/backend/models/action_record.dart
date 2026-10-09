import 'suggestion.dart';

/// One applied change, stored in the journal so it can be undone.
class ActionRecord {
  final String id;

  /// All actions from one `apply` call share a batch id ("undo all").
  final String batchId;
  final ActionType type;
  final String sourcePath;
  final String targetPath;
  final DateTime timestamp;
  final bool undone;

  const ActionRecord({
    required this.id,
    required this.batchId,
    required this.type,
    required this.sourcePath,
    required this.targetPath,
    required this.timestamp,
    this.undone = false,
  });

  ActionRecord markUndone() => ActionRecord(
        id: id,
        batchId: batchId,
        type: type,
        sourcePath: sourcePath,
        targetPath: targetPath,
        timestamp: timestamp,
        undone: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'type': type.name,
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'timestamp': timestamp.toIso8601String(),
        'undone': undone,
      };

  @override
  String toString() =>
      'ActionRecord(${type.name}: $sourcePath → $targetPath${undone ? ', undone' : ''})';
}
