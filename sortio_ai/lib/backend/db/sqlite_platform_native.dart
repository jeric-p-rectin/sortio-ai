import 'dart:io';

import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as native_sqlite;

Future<void> initializeSqlite() async {}

CommonDatabase openDatabase(String path) {
  Directory(File(path).parent.path).createSync(recursive: true);
  return native_sqlite.sqlite3.open(path);
}

CommonDatabase openInMemory() => native_sqlite.sqlite3.openInMemory();
