import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/suggestion.dart';

class ValidationResult {
  final bool ok;
  final String? reason;

  const ValidationResult.ok()
      : ok = true,
        reason = null;
  const ValidationResult.rejected(String this.reason) : ok = false;
}

/// The safety gate. Every change — whether it came from rules or the LLM —
/// passes through here before touching the disk.
///
/// Enforces: only move/rename/createFolder, only inside allowed folders,
/// never overwrite, valid file names.
class Validator {
  final List<String> _roots;
  final List<String> _canonical;

  Validator(Iterable<String> allowedRoots)
      : _roots = allowedRoots.map(p.normalize).toList(),
        _canonical = allowedRoots.map(p.canonicalize).toList();

  List<String> get roots => List.unmodifiable(_roots);

  bool isAllowed(String path) => rootOf(path) != null;

  /// The allowed root (as the caller passed it) that contains [path], or null.
  String? rootOf(String path) {
    final c = p.canonicalize(path);
    for (var i = 0; i < _canonical.length; i++) {
      final r = _canonical[i];
      if (p.equals(r, c) || p.isWithin(r, c)) return _roots[i];
    }
    return null;
  }

  static final _illegalChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  static String? checkFileName(String name) {
    if (name.trim().isEmpty) return 'Name is empty';
    if (name == '.' || name == '..') return 'Invalid name';
    if (_illegalChars.hasMatch(name)) return 'Name contains illegal characters';
    if (name.endsWith(' ') || name.endsWith('.')) {
      return 'Name cannot end with a space or dot';
    }
    if (name.length > 255) return 'Name is too long';
    return null;
  }

  /// [plannedTargets] are canonical target paths already claimed earlier in
  /// the same batch, so two suggestions cannot land on the same name.
  ValidationResult check(Suggestion s, {Set<String> plannedTargets = const {}}) {
    final target = s.targetPath;
    if (!isAllowed(target)) {
      return const ValidationResult.rejected('Destination is outside the allowed folders');
    }
    final nameError = checkFileName(p.basename(target));
    if (nameError != null) return ValidationResult.rejected(nameError);

    if (FileSystemEntity.typeSync(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return const ValidationResult.rejected('A file with that name already exists');
    }
    if (plannedTargets.contains(p.canonicalize(target))) {
      return const ValidationResult.rejected(
          'Another approved change already uses that name');
    }

    switch (s.type) {
      case ActionType.createFolder:
        return const ValidationResult.ok();
      case ActionType.move:
      case ActionType.rename:
        final source = s.sourcePath;
        if (!isAllowed(source)) {
          return const ValidationResult.rejected('File is outside the allowed folders');
        }
        if (FileSystemEntity.typeSync(source, followLinks: false) !=
            FileSystemEntityType.file) {
          return const ValidationResult.rejected('File no longer exists');
        }
        if (p.equals(source, target)) {
          return const ValidationResult.rejected('Nothing to change');
        }
        if (s.type == ActionType.rename &&
            !p.equals(p.dirname(source), p.dirname(target))) {
          return const ValidationResult.rejected('A rename cannot change the folder');
        }
        return const ValidationResult.ok();
    }
  }
}
