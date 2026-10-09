import 'dart:math';

final _rng = Random();
int _counter = 0;

/// Short unique id without pulling in a uuid package.
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final c = (_counter++ & 0xffff).toRadixString(36);
  final r = _rng.nextInt(1 << 32).toRadixString(36);
  return '$t-$c-$r';
}
