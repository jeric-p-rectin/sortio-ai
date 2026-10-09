import 'dart:io';

import 'package:path/path.dart' as p;

/// Low-level file operations. Callers must validate first (see `Validator`).

/// Rename when possible; across storage volumes fall back to
/// copy → verify size → remove original (still a move, never a loss).
Future<void> moveFile(String from, String to) async {
  final source = File(from);
  try {
    await source.rename(to);
  } on FileSystemException {
    final copy = await source.copy(to);
    if (await copy.length() != await source.length()) {
      await copy.delete();
      throw FileSystemException('Copy verification failed', from);
    }
    await source.delete();
  }
}

bool pathExists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) !=
    FileSystemEntityType.notFound;

/// `name.ext`, or `name (1).ext`, `name (2).ext`… if taken on disk or
/// already [claimed] (canonical paths) in the current batch.
/// Never returns a path that would overwrite something.
String uniqueTarget(String path, [Set<String> claimed = const {}]) {
  bool taken(String candidate) =>
      claimed.contains(p.canonicalize(candidate)) || pathExists(candidate);

  if (!taken(path)) return path;
  final dir = p.dirname(path);
  final stem = p.basenameWithoutExtension(path);
  final ext = p.extension(path);
  for (var i = 1;; i++) {
    final candidate = p.join(dir, '$stem ($i)$ext');
    if (!taken(candidate)) return candidate;
  }
}
