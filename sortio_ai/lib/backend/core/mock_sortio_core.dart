import 'dart:async';

import 'package:path/path.dart' as p;

import '../models/action_record.dart';
import '../models/ids.dart';
import '../models/results.dart';
import '../models/suggestion.dart';
import 'local_sortio_core.dart';
import 'sortio_core.dart';

/// Fake core for building the UI before the real one is wired in.
/// Never touches the file system.
class MockSortioCore implements SortioCore {
  final Duration latency;
  final List<ActionRecord> _history = [];

  MockSortioCore({this.latency = const Duration(milliseconds: 400)});

  static const _root = '/storage/emulated/0/Download';

  static final _samples = <(String, String, String, double, bool)>[
    // (file, category, reason, confidence, needsRename)
    ('IMG_2043.pdf', 'Scans', 'Looks like a scanned document with a generic name → Scans', 0.7, true),
    ('CamScanner 03-14-2026.pdf', 'Scans', 'Looks like a scanned document with a generic name → Scans', 0.7, true),
    ('Resume_Final_v3.docx', 'Documents', 'Word document → Documents', 0.95, false),
    ('Meralco_Bill_March.pdf', 'Documents', 'PDF document → Documents', 0.95, false),
    ('Screenshot_20260310-101522.png', 'Screenshots', 'Screenshot → Screenshots', 0.95, false),
    ('vacation.jpg', 'Images', 'Image → Images', 0.95, false),
    ('thesis_dataset.xlsx', 'Documents', 'Spreadsheet → Documents', 0.95, false),
    ('song.mp3', 'Audio', 'Audio file → Audio', 0.95, false),
    ('project_files.zip', 'Archives', 'Compressed archive → Archives', 0.95, false),
    ('gcash_setup.apk', 'Installers', 'Android installer → Installers', 0.95, false),
  ];

  @override
  Future<List<Suggestion>> scan(List<String> allowedFolders) async {
    await Future<void>.delayed(latency);
    final root = allowedFolders.isEmpty ? _root : allowedFolders.first;
    return [
      for (final (file, category, reason, confidence, needsRename) in _samples)
        Suggestion(
          id: newId(),
          type: ActionType.move,
          sourcePath: p.join(root, file),
          targetPath: p.join(root, category, file),
          reason: reason,
          confidence: confidence,
          category: category,
          needsRename: needsRename,
        ),
    ];
  }

  @override
  Future<ApplyResult> apply(List<Suggestion> approved) async {
    await Future<void>.delayed(latency);
    final batchId = newId();
    final applied = [
      for (final s in approved)
        ActionRecord(
          id: newId(),
          batchId: batchId,
          type: s.type,
          sourcePath: s.sourcePath,
          targetPath: s.targetPath,
          timestamp: DateTime.now(),
        ),
    ];
    _history.addAll(applied);
    return ApplyResult(batchId: batchId, applied: applied, rejected: const {});
  }

  @override
  Future<UndoResult> undo(String actionId) async {
    await Future<void>.delayed(latency);
    final i = _history.indexWhere((r) => r.id == actionId && !r.undone);
    if (i < 0) {
      return UndoResult(undone: const [], failed: {actionId: 'Unknown action'});
    }
    _history[i] = _history[i].markUndone();
    return UndoResult(undone: [_history[i]], failed: const {});
  }

  @override
  Future<UndoResult> undoBatch(String batchId) async {
    await Future<void>.delayed(latency);
    final undone = <ActionRecord>[];
    for (var i = 0; i < _history.length; i++) {
      if (_history[i].batchId == batchId && !_history[i].undone) {
        _history[i] = _history[i].markUndone();
        undone.add(_history[i]);
      }
    }
    return UndoResult(undone: undone, failed: const {});
  }

  @override
  Future<ApplyResult> quarantine(String filePath) => apply([
        Suggestion(
          id: newId(),
          type: ActionType.move,
          sourcePath: filePath,
          targetPath: p.join(p.dirname(filePath),
              LocalSortioCore.quarantineFolderName, p.basename(filePath)),
          reason: 'Moved to quarantine',
          category: LocalSortioCore.quarantineFolderName,
        ),
      ]);

  @override
  Future<List<ActionRecord>> history() async => _history.reversed.toList();

  @override
  Future<List<FileResult>> search(String query) async {
    await Future<void>.delayed(latency);
    return [
      FileResult(
        path: '$_root/Documents/2026-03_Meralco_Invoice.pdf',
        sizeBytes: 182340,
        modified: DateTime(2026, 3, 14),
        matchReason: 'name has "invoice", dated March in name',
      ),
      FileResult(
        path: '$_root/Documents/2026-03_PLDT_Invoice.pdf',
        sizeBytes: 95120,
        modified: DateTime(2026, 3, 2),
        matchReason: 'name has "invoice", dated March in name',
      ),
    ];
  }

  @override
  Stream<bool> get isOffline => Stream.value(true);
}
