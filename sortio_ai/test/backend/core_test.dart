import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sortio_ai/backend/sortio_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late Directory tmp;
  late String downloads;
  late String dataDir;
  final opened = <LocalSortioCore>[];

  LocalSortioCore open({List<String> allowed = const []}) {
    final core = LocalSortioCore(dataDir: dataDir, allowedFolders: allowed);
    opened.add(core);
    return core;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sortio_test_');
    downloads = p.join(tmp.path, 'Download');
    dataDir = p.join(tmp.path, 'appdata');
    await Directory(downloads).create();
  });

  tearDown(() async {
    for (final core in opened) {
      core.close();
    }
    opened.clear();
    await tmp.delete(recursive: true);
  });

  Future<File> touch(String name, [String content = 'x']) =>
      File(p.join(downloads, name)).writeAsString(content);

  group('Validator', () {
    test('rejects destinations outside allowed folders', () async {
      final f = await touch('a.pdf');
      final v = Validator([downloads]);
      final r = v.check(Suggestion(
        id: '1',
        type: ActionType.move,
        sourcePath: f.path,
        targetPath: p.join(tmp.path, 'elsewhere', 'a.pdf'),
        reason: '',
      ));
      expect(r.ok, isFalse);
    });

    test('rejects overwriting an existing file', () async {
      final a = await touch('a.pdf');
      await touch('b.pdf');
      final r = Validator([downloads]).check(Suggestion(
        id: '1',
        type: ActionType.rename,
        sourcePath: a.path,
        targetPath: p.join(downloads, 'b.pdf'),
        reason: '',
      ));
      expect(r.ok, isFalse);
      expect(r.reason, contains('already exists'));
    });

    test('rejects illegal names and path traversal', () async {
      final a = await touch('a.pdf');
      final v = Validator([downloads]);
      Suggestion rename(String name) => Suggestion(
            id: '1',
            type: ActionType.rename,
            sourcePath: a.path,
            targetPath: p.join(downloads, name),
            reason: '',
          );
      expect(v.check(rename('bad:name.pdf')).ok, isFalse);
      expect(v.check(rename(p.join('..', 'escape.pdf'))).ok, isFalse);
      expect(v.check(rename('2026-03_Meralco_Invoice.pdf')).ok, isTrue);
    });
  });

  group('LocalSortioCore', () {
    test('scan → apply → undoBatch round trip', () async {
      await touch('report.pdf');
      await touch('photo.jpg');
      await touch('IMG_2043.pdf');
      await touch('notes.xyz'); // unknown: left alone
      final core = open();

      final suggestions = await core.scan([downloads]);
      expect(suggestions.map((s) => s.fileName),
          containsAll(['report.pdf', 'photo.jpg', 'IMG_2043.pdf']));
      expect(suggestions, hasLength(3));
      // Scanning changes nothing.
      expect(File(p.join(downloads, 'report.pdf')).existsSync(), isTrue);

      final result = await core.apply(suggestions);
      expect(result.rejected, isEmpty);
      expect(result.filesChanged, 3);
      expect(File(p.join(downloads, 'Documents', 'report.pdf')).existsSync(),
          isTrue);
      expect(File(p.join(downloads, 'Scans', 'IMG_2043.pdf')).existsSync(),
          isTrue);

      final undo = await core.undoBatch(result.batchId);
      expect(undo.failed, isEmpty);
      expect(File(p.join(downloads, 'report.pdf')).existsSync(), isTrue);
      expect(File(p.join(downloads, 'photo.jpg')).existsSync(), isTrue);
      // Folders created by the batch are removed once empty.
      expect(Directory(p.join(downloads, 'Documents')).existsSync(), isFalse);
    });

    test('never overwrites: name collisions get a suffix', () async {
      await touch('report.pdf', 'new');
      await Directory(p.join(downloads, 'Documents')).create();
      await File(p.join(downloads, 'Documents', 'report.pdf'))
          .writeAsString('old');
      final core = open();

      final s = await core.scan([downloads]);
      expect(s.single.targetName, 'report (1).pdf');
      await core.apply(s);
      expect(
          File(p.join(downloads, 'Documents', 'report.pdf')).readAsStringSync(),
          'old');
      expect(
          File(p.join(downloads, 'Documents', 'report (1).pdf'))
              .readAsStringSync(),
          'new');
    });

    test('a single rename can be undone, and survives restart', () async {
      final scan = await touch('IMG_2043.pdf');
      final core = open(allowed: [downloads]);
      final result = await core.apply([
        Suggestion(
          id: 's1',
          type: ActionType.rename,
          sourcePath: scan.path,
          targetPath: p.join(downloads, '2026-03_Meralco_Invoice.pdf'),
          reason: 'AI rename',
        ),
      ]);
      expect(result.rejected, isEmpty);

      // New instance = app restart; journal is read from disk.
      final restarted = open(allowed: [downloads]);
      final history = await restarted.history();
      expect(history, hasLength(1));
      final undo = await restarted.undo(history.single.id);
      expect(undo.failed, isEmpty);
      expect(scan.existsSync(), isTrue);
      expect((await restarted.history()).single.undone, isTrue);
    });

    test('quarantine moves instead of deleting, and can be restored', () async {
      final f = await touch('junk.pdf');
      final core = open(allowed: [downloads]);
      final q = await core.quarantine(f.path);
      expect(q.rejected, isEmpty);
      expect(f.existsSync(), isFalse);
      expect(
          File(p.join(downloads, LocalSortioCore.quarantineFolderName,
                  'junk.pdf'))
              .existsSync(),
          isTrue);
      await core.undoBatch(q.batchId);
      expect(f.existsSync(), isTrue);
    });

    test('apply rejects anything outside the allowed folders', () async {
      final outside = File(p.join(tmp.path, 'secret.pdf'))..writeAsStringSync('x');
      final core = open(allowed: [downloads]);
      final r = await core.apply([
        Suggestion(
          id: 's1',
          type: ActionType.move,
          sourcePath: outside.path,
          targetPath: p.join(downloads, 'secret.pdf'),
          reason: '',
        ),
      ]);
      expect(r.applied, isEmpty);
      expect(r.rejected['s1'], contains('outside'));
      expect(outside.existsSync(), isTrue);
    });
  });

  group('Search', () {
    test('finds "invoice from March" by name or modified date', () async {
      await Directory(p.join(downloads, 'Documents')).create();
      await File(p.join(downloads, 'Documents', '2026-03_Meralco_Invoice.pdf'))
          .writeAsString('x');
      final byDate = await touch('PLDT_invoice.pdf');
      await byDate.setLastModified(DateTime(2026, 3, 20));
      final other = await touch('2026-05_Meralco_Invoice.pdf');
      await other.setLastModified(DateTime(2026, 5, 2));

      final core = open(allowed: [downloads]);
      final names = (await core.search('invoice from March')).map((r) => r.name);
      expect(names,
          unorderedEquals(['2026-03_Meralco_Invoice.pdf', 'PLDT_invoice.pdf']));
    });

    test('month filter uses the date printed inside a scan', () async {
      final scan = await touch('scan_0001.pdf');
      await scan.setLastModified(DateTime(2026, 10, 9)); // not January
      final core = open(allowed: [downloads]);
      await core.refreshIndex();
      core.saveOcrText(scan.path,
          'PAYSLIP Employee: Juan Dela Cruz Pay Period: January 1-15, 2026 Net Pay 13,543.70');

      final hits = await core.search('payslip january');
      expect(hits.single.name, 'scan_0001.pdf');
      expect(hits.single.matchReason, contains('document dated January'));
      expect(await core.search('payslip march'), isEmpty);
    });

    test('finds scans by the text inside them (OCR)', () async {
      final scan = await touch('IMG_2043.pdf');
      await touch('notes.pdf');
      final core = open(allowed: [downloads]);
      await core.refreshIndex();

      expect(core.filesNeedingOcr().map((f) => f.name),
          containsAll(['IMG_2043.pdf', 'notes.pdf']));
      core.saveOcrText(scan.path,
          'MANILA ELECTRIC COMPANY (MERALCO) Statement of Account March 2026');
      expect(core.filesNeedingOcr().map((f) => f.name), isNot(contains('IMG_2043.pdf')));

      final hits = await core.search('meralco statement');
      expect(hits.single.name, 'IMG_2043.pdf');
      expect(hits.single.matchReason, contains('document text'));
    });
  });

  group('Index', () {
    test('scan sends executables to quarantine; wipe forgets memory and logs',
        () async {
      final exe = await touch('setup_v2.exe');
      final core = open();
      final s = await core.scan([downloads]);
      expect(s.single.targetPath,
          p.join(downloads, LocalSortioCore.quarantineFolderName, 'setup_v2.exe'));

      await core.apply(s);
      core.saveOcrText(
          p.join(downloads, LocalSortioCore.quarantineFolderName, 'setup_v2.exe'),
          'x');
      expect(await core.history(), isNotEmpty);
      core.wipeMemory();
      expect(await core.history(), isEmpty);
      expect(core.ocrTextFor(p.join(
              downloads, LocalSortioCore.quarantineFolderName, 'setup_v2.exe')),
          isNull);
      expect(exe.existsSync(), isFalse); // files untouched by wipe
    });

    test('photo folders: only recent photos of documents are suggested', () async {
      final camera = p.join(tmp.path, 'DCIM', 'Camera');
      await Directory(camera).create(recursive: true);
      Future<File> shoot(String name) => File(p.join(camera, name)).writeAsString('x');
      final fresh = await shoot('IMG_20261009_101500.jpg'); // not OCR'd yet
      final receipt = await shoot('IMG_20261008_090000.jpg');
      final selfie = await shoot('IMG_20261007_180000.jpg');
      final old = await shoot('IMG_20260101_120000.jpg');
      await old.setLastModified(DateTime.now().subtract(const Duration(days: 60)));
      await shoot('VID_20261009.mp4');

      final core = open(allowed: [camera])..photoRoots = {p.normalize(camera)};
      await core.refreshIndex();
      core.saveOcrText(receipt.path,
          'OFFICIAL RECEIPT 7-Eleven Store Katipunan Ave Quezon City TOTAL 58.00 CASH CHANGE');
      core.saveOcrText(selfie.path, 'GO TEAM');
      core.saveOcrText(old.path, 'OFFICIAL RECEIPT Mercury Drug TOTAL 120.00 thank you come again');

      final s = {for (final x in await core.scan([camera])) x.fileName: x};
      expect(s.keys, unorderedEquals([p.basename(fresh.path), p.basename(receipt.path)]));
      expect(s[p.basename(fresh.path)]!.needsDocumentCheck, isTrue);
      final r = s[p.basename(receipt.path)]!;
      expect(r.needsDocumentCheck, isFalse);
      expect(r.needsRename, isTrue);
      expect(r.category, LocalSortioCore.photoCategory);
    });

    test('nested folders created by apply are all removed by undo', () async {
      final f = await touch('junk.exe');
      final core = open(allowed: [downloads]);
      final q = await core.quarantine(f.path);
      expect(q.rejected, isEmpty);
      expect(Directory(p.join(downloads, 'Quarantine', 'holding_bin')).existsSync(), isTrue);
      await core.undoBatch(q.batchId);
      expect(f.existsSync(), isTrue);
      expect(Directory(p.join(downloads, 'Quarantine')).existsSync(), isFalse);
    });

    test('house rules win over category rules and read OCR text', () async {
      await touch('Zoom_Receipt_March.pdf');
      final scan = await touch('IMG_2043.pdf');
      await touch('report.pdf');
      final core = open(allowed: [downloads])
        ..houseRules = HouseRules.parse('Always file Zoom receipts under Finance');
      await core.refreshIndex();
      core.saveOcrText(scan.path, 'ZOOM VIDEO COMMUNICATIONS official receipt');

      final s = {for (final x in await core.scan([downloads])) x.fileName: x};
      expect(s['Zoom_Receipt_March.pdf']!.targetPath,
          p.join(downloads, 'Finance', 'Zoom_Receipt_March.pdf'));
      expect(s['Zoom_Receipt_March.pdf']!.reason, contains('Your rule'));
      expect(s['IMG_2043.pdf']!.category, 'Finance'); // matched via OCR text
      expect(s['IMG_2043.pdf']!.needsRename, isTrue); // still gets an AI name
      expect(s['report.pdf']!.category, 'Documents');
    });

    test('chats and settings persist across restarts; wipe clears chats', () async {
      final first = open();
      final at = DateTime(2026, 10, 10, 4, 0);
      first.db.saveChat('c1', 'Tidy my downloads', at);
      first.db.saveMessage('c1', StoredMessage(id: 'u1', isUser: true, text: 'tidy my downloads', at: at));
      first.db.saveMessage('c1', StoredMessage(id: 'a1', isUser: false, text: 'Found 3 files', at: at));
      first.db.saveMessage('c1', StoredMessage(id: 'a1', isUser: false, text: 'Found 4 files', at: at));
      first.db.saveSetting('house_rules', 'Put payslips in Work');

      final restarted = open();
      final chats = restarted.db.chats();
      expect(chats.single.title, 'Tidy my downloads');
      expect(chats.single.messages.map((m) => m.text), ['tidy my downloads', 'Found 4 files']);
      expect(restarted.db.setting('house_rules'), 'Put payslips in Work');

      restarted.wipeMemory();
      expect(restarted.db.chats(), isEmpty);
      expect(restarted.db.setting('house_rules'), 'Put payslips in Work');
    });

    test('refresh is incremental and keeps OCR cache for unchanged files',
        () async {
      final a = await touch('a.pdf');
      await touch('b.jpg');
      final core = open(allowed: [downloads]);

      final first = await core.refreshIndex();
      expect(first.addedOrChanged, 2);
      core.saveOcrText(a.path, 'hello');

      final second = await core.refreshIndex();
      expect(second.addedOrChanged, 0);
      expect(core.ocrTextFor(a.path), 'hello');

      // Content changed → cache dropped so it gets re-OCR'd.
      await a.writeAsString('different content');
      final third = await core.refreshIndex();
      expect(third.addedOrChanged, 1);
      expect(core.ocrTextFor(a.path), isNull);

      await File(p.join(downloads, 'b.jpg')).delete();
      expect((await core.refreshIndex()).removed, 1);
    });

    test('OCR cache follows the file through apply and undo', () async {
      final scan = await touch('IMG_2043.pdf');
      final core = open(allowed: [downloads]);
      await core.refreshIndex();
      core.saveOcrText(scan.path, 'Meralco bill');

      final renamed = p.join(downloads, '2026-03_Meralco_Bill.pdf');
      final result = await core.apply([
        Suggestion(
          id: 's1',
          type: ActionType.rename,
          sourcePath: scan.path,
          targetPath: renamed,
          reason: 'AI rename',
        ),
      ]);
      expect(core.ocrTextFor(renamed), 'Meralco bill');
      expect(core.ocrTextFor(scan.path), isNull);

      await core.undoBatch(result.batchId);
      expect(core.ocrTextFor(scan.path), 'Meralco bill');
    });
  });

  group('AI rename', () {
    const ocrText = 'MERALCO Statement of Account Bill Date: March 16, 2026';

    test('scan → aiRename → apply renames and files the scan', () async {
      await touch('IMG_2043.pdf');
      await touch('report.pdf');
      final core = open();
      final llm = FakeLlm({'issuer': 'MERALCO', 'doc_type': 'Bill'});
      var ocrCalls = 0;

      final suggestions = await core.scan([downloads]);
      final updated = await core
          .aiRename(suggestions, RenameService(llm), ocr: (_) async {
        ocrCalls++;
        return ocrText;
      }).toList();

      expect(updated, hasLength(1)); // only the scan needs a rename
      final s = updated.single;
      expect(s.id, suggestions.firstWhere((x) => x.fileName == 'IMG_2043.pdf').id);
      expect(s.targetName, '2026-03_Meralco_Statement.pdf');
      expect(s.aiNamed, isTrue);
      expect(s.reason, contains('Meralco statement from March 2026'));

      final merged = [
        for (final x in suggestions) x.id == s.id ? s : x,
      ];
      final result = await core.apply(merged);
      expect(result.rejected, isEmpty);
      expect(
          File(p.join(downloads, 'Scans', '2026-03_Meralco_Statement.pdf'))
              .existsSync(),
          isTrue);
      expect(ocrCalls, 1);
    });

    test('OCR and model results are cached across rescans', () async {
      await touch('IMG_2043.pdf');
      final core = open();
      final llm = FakeLlm({'issuer': 'MERALCO', 'doc_type': 'Bill'});
      var ocrCalls = 0;
      Future<String> ocr(String _) async {
        ocrCalls++;
        return ocrText;
      }

      await core.aiRename(await core.scan([downloads]), RenameService(llm), ocr: ocr).toList();
      expect((llm.calls, ocrCalls), (1, 1));

      // Rescan: the cached AI name is used directly, no OCR, no model call.
      final again = await core.scan([downloads]);
      expect(again.single.targetName, '2026-03_Meralco_Statement.pdf');
      expect(again.single.aiNamed, isTrue);
      expect(again.single.needsRename, isFalse);
      await core.aiRename(again, RenameService(llm), ocr: ocr).toList();
      expect((llm.calls, ocrCalls), (1, 1));
    });

    test('model failures skip the file instead of failing the batch', () async {
      await touch('IMG_1.pdf');
      await touch('IMG_2.pdf');
      final core = open();
      final updated = await core
          .aiRename(await core.scan([downloads]),
              RenameService(FakeLlm({}, fail: true)),
              ocr: (_) async => ocrText)
          .toList();
      expect(updated, isEmpty);
    });

    test('two scans with the same AI name never collide', () async {
      await touch('IMG_1.pdf');
      await touch('IMG_2.pdf');
      final core = open();
      final updated = await core
          .aiRename(await core.scan([downloads]),
              RenameService(FakeLlm({'issuer': 'MERALCO', 'doc_type': 'Bill'})),
              ocr: (_) async => ocrText)
          .toList();
      expect(updated.map((s) => s.targetName),
          unorderedEquals(['2026-03_Meralco_Statement.pdf', '2026-03_Meralco_Statement (1).pdf']));
    });
  });
}
