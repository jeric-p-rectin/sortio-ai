import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backend/design_tokens.dart';
import 'frontend/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const SortioApp());
}
