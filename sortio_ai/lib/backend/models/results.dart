import 'package:path/path.dart' as p;

import 'action_record.dart';
import 'suggestion.dart';

/// Result of `SortioCore.apply`.
class ApplyResult {
  final String batchId;
  final List<ActionRecord> applied;

  /// Suggestion id → why it was rejected by the validator or failed.
  final Map<String, String> rejected;

  const ApplyResult({
    required this.batchId,
    required this.applied,
    required this.rejected,
  });

  /// Number of files moved/renamed (excludes auto-created folders).
  int get filesChanged =>
      applied.where((a) => a.type != ActionType.createFolder).length;
}

/// Result of `SortioCore.undo` / `undoBatch`.
class UndoResult {
  final List<ActionRecord> undone;

  /// Action id → why it could not be undone.
  final Map<String, String> failed;

  const UndoResult({required this.undone, required this.failed});
}

/// A search hit.
class FileResult {
  final String path;
  final int sizeBytes;
  final DateTime modified;
  final String? matchReason;

  const FileResult({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.matchReason,
  });

  String get name => p.basename(path);
}

/// Counts from `LocalSortioCore.refreshIndex`.
class IndexStats {
  final int total;
  final int addedOrChanged;
  final int removed;

  const IndexStats(this.total, this.addedOrChanged, this.removed);

  @override
  String toString() =>
      'IndexStats(total: $total, addedOrChanged: $addedOrChanged, removed: $removed)';
}
