import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backend/db/sqlite_platform.dart' as sqlite_platform;
import 'backend/design_tokens.dart';
import 'frontend/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sqlite_platform.initializeSqlite();

  if (!kIsWeb) {
    // Portrait phone app, dark system chrome to match the Sortio theme.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SortioColors.page,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  runApp(const SortioApp());
}
