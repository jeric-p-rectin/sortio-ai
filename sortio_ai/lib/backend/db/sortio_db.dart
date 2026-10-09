import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../models/action_record.dart';
import '../models/suggestion.dart';

/// A saved chat (History screen) and its messages.
class StoredChat {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<StoredMessage> messages;

  const StoredChat({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });
}

class StoredMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime at;

  const StoredMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.at,
  });
}

/// A row of the file index.
class IndexedFile {
  final int id;
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String? ocrText;
  final String? aiName;

  const IndexedFile({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    this.ocrText,
    this.aiName,
  });

  static IndexedFile fromRow(Row r) => IndexedFile(
        id: r['id'] as int,
        path: r['path'] as String,
        name: r['name'] as String,
        size: r['size'] as int,
        modified: DateTime.fromMillisecondsSinceEpoch(r['mtime'] as int),
        ocrText: r['ocr_text'] as String?,
        aiName: r['ai_name'] as String?,
      );
}

/// On-device SQLite store: the file index (with cached OCR text and AI
/// names, full-text searchable) and the action journal used for undo.
///
/// Caching is the main efficiency win: OCR and the LLM run once per file
/// version, and the cache follows the file when Sortio moves or renames it.
class SortioDb {
  static const _schemaVersion = 3;
  static const maxOcrChars = 4000;

  final Database _db;

  SortioDb.open(String dataDir)
      : _db = _openFile(p.join(dataDir, 'sortio.db')) {
    _migrate();
  }

  SortioDb.inMemory() : _db = sqlite3.openInMemory() {
    _migrate();
  }

  static Database _openFile(String path) {
    Directory(p.dirname(path)).createSync(recursive: true);
    return sqlite3.open(path);
  }

  void close() => _db.close();

  void _migrate() {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA synchronous = NORMAL');
    final version = _db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version >= _schemaVersion) return;
    if (version < 1) _migrateV1();
    if (version < 2) _migrateV2();
    if (version < 3) _migrateV3();
    _db.execute('PRAGMA user_version = $_schemaVersion');
  }

  /// v1: file index (+ FTS5) and the action journal.
  void _migrateV1() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS files (
        id        INTEGER PRIMARY KEY,
        path      TEXT NOT NULL UNIQUE,
        name      TEXT NOT NULL,
        size      INTEGER NOT NULL,
        mtime     INTEGER NOT NULL,   -- ms since epoch
        ocr_text  TEXT,               -- NULL = not OCR'd yet
        ai_name   TEXT                -- cached AI rename suggestion
      );
      CREATE INDEX IF NOT EXISTS files_mtime ON files(mtime);

      CREATE VIRTUAL TABLE IF NOT EXISTS files_fts USING fts5(
        name, ocr_text,
        content = 'files', content_rowid = 'id',
        tokenize = 'unicode61 remove_diacritics 2'
      );
      CREATE TRIGGER IF NOT EXISTS files_ai AFTER INSERT ON files BEGIN
        INSERT INTO files_fts(rowid, name, ocr_text)
        VALUES (new.id, new.name, new.ocr_text);
      END;
      CREATE TRIGGER IF NOT EXISTS files_ad AFTER DELETE ON files BEGIN
        INSERT INTO files_fts(files_fts, rowid, name, ocr_text)
        VALUES ('delete', old.id, old.name, old.ocr_text);
      END;
      CREATE TRIGGER IF NOT EXISTS files_au AFTER UPDATE OF name, ocr_text ON files BEGIN
        INSERT INTO files_fts(files_fts, rowid, name, ocr_text)
        VALUES ('delete', old.id, old.name, old.ocr_text);
        INSERT INTO files_fts(rowid, name, ocr_text)
        VALUES (new.id, new.name, new.ocr_text);
      END;

      CREATE TABLE IF NOT EXISTS actions (
        seq       INTEGER PRIMARY KEY AUTOINCREMENT,
        id        TEXT NOT NULL UNIQUE,
        batch_id  TEXT NOT NULL,
        type      TEXT NOT NULL,
        source    TEXT NOT NULL,
        target    TEXT NOT NULL,
        ts        INTEGER NOT NULL,
        undone    INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS actions_batch ON actions(batch_id);
    ''');
  }

  /// v2: saved chats (History screen) and small app settings (house rules).
  void _migrateV2() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS chats (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        updated_at  INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS chat_messages (
        seq      INTEGER PRIMARY KEY AUTOINCREMENT,
        id       TEXT NOT NULL,
        chat_id  TEXT NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
        is_user  INTEGER NOT NULL,
        text     TEXT NOT NULL,
        ts       INTEGER NOT NULL,
        UNIQUE (chat_id, id)
      );
      CREATE INDEX IF NOT EXISTS chat_messages_chat ON chat_messages(chat_id, seq);
      CREATE TABLE IF NOT EXISTS settings (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      );
    ''');
  }

  T transaction<T>(T Function() body) {
    _db.execute('BEGIN');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// v3: content hash per file (duplicate finder) and learned habits.
  void _migrateV3() {
    final columns = _db.select('PRAGMA table_info(files)').map((r) => r['name']);
    if (!columns.contains('hash')) {
      _db.execute('ALTER TABLE files ADD COLUMN hash TEXT');
    }
    _db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        key     TEXT NOT NULL,   -- "ext:.pdf" or "issuer:meralco"
        folder  TEXT NOT NULL,   -- relative to the allowed folder
        count   INTEGER NOT NULL,
        PRIMARY KEY (key, folder)
      );
    ''');
  }

  // --- File index ------------------------------------------------------------

  /// path → (size, mtimeMs) for every indexed file.
  Map<String, (int, int)> fileSignatures() => {
        for (final r in _db.select('SELECT path, size, mtime FROM files'))
          r['path'] as String: (r['size'] as int, r['mtime'] as int),
      };

  /// Insert new files / update changed ones. A changed file loses its cached
  /// OCR text and AI name, since its content may be different now.
  void upsertFiles(Iterable<(String path, int size, int mtimeMs)> files) {
    final stmt = _db.prepare('''
      INSERT INTO files (path, name, size, mtime) VALUES (?, ?, ?, ?)
      ON CONFLICT(path) DO UPDATE SET
        size = excluded.size, mtime = excluded.mtime,
        ocr_text = NULL, ai_name = NULL, hash = NULL
    ''');
    try {
      transaction(() {
        for (final (path, size, mtime) in files) {
          stmt.execute([path, p.basename(path), size, mtime]);
        }
      });
    } finally {
      stmt.close();
    }
  }

  void removeFiles(Iterable<String> paths) {
    final stmt = _db.prepare('DELETE FROM files WHERE path = ?');
    try {
      transaction(() {
        for (final path in paths) {
          stmt.execute([path]);
        }
      });
    } finally {
      stmt.close();
    }
  }

  /// Keep the index (and its OCR/AI cache) attached to a file Sortio moved.
  void movePath(String from, String to) {
    _db.execute('DELETE FROM files WHERE path = ?', [to]);
    _db.execute(
        'UPDATE files SET path = ?, name = ? WHERE path = ?', [to, p.basename(to), from]);
  }

  IndexedFile? file(String path) {
    final rows = _db.select('SELECT * FROM files WHERE path = ?', [path]);
    return rows.isEmpty ? null : IndexedFile.fromRow(rows.first);
  }

  int get fileCount =>
      _db.select('SELECT count(*) FROM files').first.columnAt(0) as int;

  /// Files that are OCR candidates (scannable type) and not OCR'd yet.
  List<IndexedFile> filesNeedingOcr({int limit = 50}) => _db
      .select('''
        SELECT * FROM files
        WHERE ocr_text IS NULL AND (
          lower(name) LIKE '%.pdf' OR lower(name) LIKE '%.jpg' OR
          lower(name) LIKE '%.jpeg' OR lower(name) LIKE '%.png' OR
          lower(name) LIKE '%.webp' OR lower(name) LIKE '%.heic')
        ORDER BY mtime DESC LIMIT ?
      ''', [limit])
      .map(IndexedFile.fromRow)
      .toList();

  /// Store OCR text. An empty string marks "OCR'd, no text found" so the
  /// file is not retried.
  void saveOcrText(String path, String text) {
    final trimmed =
        text.length > maxOcrChars ? text.substring(0, maxOcrChars) : text;
    _db.execute('UPDATE files SET ocr_text = ? WHERE path = ?', [trimmed, path]);
  }

  /// "Wipe AI memory & logs": forget cached OCR text, AI names, chats and
  /// the action history. Files on disk and settings are not touched.
  void wipe() => transaction(() {
        _db.execute('DELETE FROM actions');
        _db.execute('DELETE FROM habits');
        _db.execute('DELETE FROM chat_messages');
        _db.execute('DELETE FROM chats');
        _db.execute('UPDATE files SET ocr_text = NULL, ai_name = NULL');
      });

  String? fileHash(String path) {
    final rows = _db.select('SELECT hash FROM files WHERE path = ?', [path]);
    return rows.isEmpty ? null : rows.first['hash'] as String?;
  }

  void saveFileHash(String path, String hash) =>
      _db.execute('UPDATE files SET hash = ? WHERE path = ?', [hash, path]);

  /// Forget AI names (e.g. after the naming template changed).
  void clearAiNames() => _db.execute('UPDATE files SET ai_name = NULL');

  // --- Learned habits ----------------------------------------------------------

  void recordHabit(String key, String folder) => _db.execute(
        'INSERT INTO habits (key, folder, count) VALUES (?, ?, 1) '
        'ON CONFLICT(key, folder) DO UPDATE SET count = count + 1',
        [key, folder],
      );

  /// The folder most often chosen for [key], once chosen at least [minCount]
  /// times.
  String? habitFolder(String key, {int minCount = 2}) {
    final rows = _db.select(
      'SELECT folder FROM habits WHERE key = ? AND count >= ? '
      'ORDER BY count DESC LIMIT 1',
      [key, minCount],
    );
    return rows.isEmpty ? null : rows.first['folder'] as String;
  }

  /// All learned habits, strongest first (for "what did you learn?").
  List<(String key, String folder, int count)> habits() => [
        for (final r in _db.select('SELECT * FROM habits ORDER BY count DESC'))
          (r['key'] as String, r['folder'] as String, r['count'] as int),
      ];

  void saveAiName(String path, String aiName) =>
      _db.execute('UPDATE files SET ai_name = ? WHERE path = ?', [aiName, path]);

  /// Full-text search over file names and OCR text, best matches first.
  /// [keywords] are matched as prefixes ("invoic" finds "invoice").
  List<IndexedFile> searchText(List<String> keywords, {int limit = 200}) {
    final match = keywords
        .map((k) => '"${k.replaceAll('"', '""')}"*')
        .join(' AND ');
    return _db
        .select('''
          SELECT f.* FROM files_fts
          JOIN files f ON f.id = files_fts.rowid
          WHERE files_fts MATCH ?
          ORDER BY bm25(files_fts, 10.0, 1.0)
          LIMIT ?
        ''', [match, limit])
        .map(IndexedFile.fromRow)
        .toList();
  }

  List<IndexedFile> recentFiles({int limit = 2000}) => _db
      .select('SELECT * FROM files ORDER BY mtime DESC LIMIT ?', [limit])
      .map(IndexedFile.fromRow)
      .toList();

  // --- Chats -----------------------------------------------------------------

  /// All chats, newest first, with their messages in order.
  List<StoredChat> chats() {
    final messages = <String, List<StoredMessage>>{};
    for (final r in _db.select('SELECT * FROM chat_messages ORDER BY seq')) {
      (messages[r['chat_id'] as String] ??= []).add(StoredMessage(
        id: r['id'] as String,
        isUser: (r['is_user'] as int) != 0,
        text: r['text'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
      ));
    }
    return [
      for (final r in _db.select('SELECT * FROM chats ORDER BY updated_at DESC'))
        StoredChat(
          id: r['id'] as String,
          title: r['title'] as String,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
          messages: messages[r['id']] ?? const [],
        ),
    ];
  }

  void saveChat(String id, String title, DateTime updatedAt) => _db.execute(
        'INSERT INTO chats (id, title, updated_at) VALUES (?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET title = excluded.title, '
        'updated_at = excluded.updated_at',
        [id, title, updatedAt.millisecondsSinceEpoch],
      );

  /// Inserts a message, or replaces its text if it already exists.
  void saveMessage(String chatId, StoredMessage m) => _db.execute(
        'INSERT INTO chat_messages (id, chat_id, is_user, text, ts) '
        'VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(chat_id, id) DO UPDATE SET text = excluded.text',
        [m.id, chatId, m.isUser ? 1 : 0, m.text, m.at.millisecondsSinceEpoch],
      );

  /// Removes one chat and its messages (the History swipe-to-delete).
  void deleteChat(String id) => transaction(() {
        _db.execute('DELETE FROM chat_messages WHERE chat_id = ?', [id]);
        _db.execute('DELETE FROM chats WHERE id = ?', [id]);
      });

  void deleteAllChats() => transaction(() {
        _db.execute('DELETE FROM chat_messages');
        _db.execute('DELETE FROM chats');
      });

  // --- Settings --------------------------------------------------------------

  String? setting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void saveSetting(String key, String value) => _db.execute(
        'INSERT INTO settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [key, value],
      );

  // --- Action journal --------------------------------------------------------

  void addAction(ActionRecord r) => _db.execute(
        'INSERT INTO actions (id, batch_id, type, source, target, ts, undone) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          r.id,
          r.batchId,
          r.type.name,
          r.sourcePath,
          r.targetPath,
          r.timestamp.millisecondsSinceEpoch,
          r.undone ? 1 : 0,
        ],
      );

  void markUndone(String id) =>
      _db.execute('UPDATE actions SET undone = 1 WHERE id = ?', [id]);

  /// Newest first.
  List<ActionRecord> actions({int limit = 500}) => _db
      .select('SELECT * FROM actions ORDER BY seq DESC LIMIT ?', [limit])
      .map(_actionFromRow)
      .toList();

  ActionRecord? action(String id) {
    final rows = _db.select('SELECT * FROM actions WHERE id = ?', [id]);
    return rows.isEmpty ? null : _actionFromRow(rows.first);
  }

  /// In the order they were applied.
  List<ActionRecord> batch(String batchId) => _db
      .select('SELECT * FROM actions WHERE batch_id = ? ORDER BY seq', [batchId])
      .map(_actionFromRow)
      .toList();

  static ActionRecord _actionFromRow(Row r) => ActionRecord(
        id: r['id'] as String,
        batchId: r['batch_id'] as String,
        type: ActionType.values.byName(r['type'] as String),
        sourcePath: r['source'] as String,
        targetPath: r['target'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
        undone: (r['undone'] as int) != 0,
      );
}
