import '../models/action_record.dart';
import '../models/results.dart';
import '../models/suggestion.dart';

/// The contract between the Flutter UI and the on-device core.
/// The UI can develop against `MockSortioCore` and swap in
/// `LocalSortioCore` without code changes.
abstract class SortioCore {
  /// Look at the top level of each allowed folder and propose tidy-ups.
  /// Never changes anything.
  Future<List<Suggestion>> scan(List<String> allowedFolders);

  /// Apply only the suggestions the user approved. Each one is re-checked by
  /// the validator; rejected ones are reported, not applied.
  Future<ApplyResult> apply(List<Suggestion> approved);

  /// Undo a single action.
  Future<UndoResult> undo(String actionId);

  /// Undo everything from one `apply` call ("Undo all").
  Future<UndoResult> undoBatch(String batchId);

  /// Move a file into the quarantine folder instead of deleting it.
  /// Restore it with [undo] / [undoBatch].
  Future<ApplyResult> quarantine(String filePath);

  /// Every applied action, newest first.
  Future<List<ActionRecord>> history();

  /// Plain-language search, e.g. "invoice from March". Matches file names
  /// and the text inside scanned documents.
  Future<List<FileResult>> search(String query);

  /// Emits true while the device has no network connection (privacy panel).
  Stream<bool> get isOffline;
}
