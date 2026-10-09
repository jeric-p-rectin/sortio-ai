import 'dart:io';

/// Offline = no non-loopback network interface is up. Reads local interface
/// state only; never sends anything.
Future<bool> checkOffline() async {
  try {
    final interfaces = await NetworkInterface.list(includeLoopback: false);
    return interfaces.isEmpty;
  } on Object {
    return true;
  }
}

/// Emits the offline state now and then every [interval] (privacy panel).
Stream<bool> offlineStatus({Duration interval = const Duration(seconds: 3)}) async* {
  while (true) {
    yield await checkOffline();
    await Future<void>.delayed(interval);
  }
}
