import 'package:sqlite3/wasm.dart';

WasmSqlite3? _sqlite;

Future<void> initializeSqlite() async {
  if (_sqlite != null) return;

  final sqlite = await WasmSqlite3.loadFromUrlString('sqlite3.wasm');
  sqlite.registerVirtualFileSystem(
    await IndexedDbFileSystem.open(dbName: 'sortio_ai_sqlite'),
    makeDefault: true,
  );
  _sqlite = sqlite;
}

CommonDatabase openDatabase(String _) {
  return _initializedSqlite().open('/sortio.db');
}

CommonDatabase openInMemory() => _initializedSqlite().openInMemory();

WasmSqlite3 _initializedSqlite() {
  final sqlite = _sqlite;
  if (sqlite == null) {
    throw StateError('SQLite on the web has not been initialized.');
  }
  return sqlite;
}
