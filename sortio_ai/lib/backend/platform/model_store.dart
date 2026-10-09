import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Where the on-device model lives: app-private storage, so it is removed on
/// uninstall and never shows up in the user's folders.
///
/// Release APKs carry the model in `android/app/src/main/assets/models/`
/// (uncompressed); [ensureInstalled] streams it out once on first launch.
class ModelStore {
  static const fileName = 'qwen3-0.6b-q4_k_m.gguf';
  static const assetPath = 'models/$fileName';
  static const _channel = MethodChannel('sortio/model');

  final String dataDir;

  const ModelStore(this.dataDir);

  String get modelPath => p.join(dataDir, 'models', fileName);

  /// The model file if it is present and plausibly complete, else null.
  String? find() {
    final file = File(modelPath);
    if (!file.existsSync()) return null;
    // A truncated copy would crash llama.cpp; a real Q4 0.6B is ~500 MB.
    return file.lengthSync() > 100 * 1024 * 1024 ? file.path : null;
  }

  /// Installs the model bundled in the APK if needed, then returns its path
  /// (null when this build has no bundled model and none was side-loaded).
  Future<String?> ensureInstalled() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>(
          'installBundledModel',
          {'asset': assetPath, 'dest': modelPath},
        );
      } on MissingPluginException {
        // Not running in the Sortio Android shell (tests, other platforms).
      } on PlatformException catch (e) {
        debugPrint('Bundled model install failed: ${e.message}');
      }
    }
    return find();
  }
}
