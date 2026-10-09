// ============================================================================
// Sortio AI — frontend/app.dart
//
// App root: the MaterialApp, wired to the backend router and theme.
// ============================================================================

import 'package:flutter/material.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/routes.dart';
import 'home_shell.dart';

class SortioApp extends StatelessWidget {
  const SortioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sortio AI — Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SortioColors.page,
        colorScheme: const ColorScheme.dark(
          primary: SortioColors.accent,
          secondary: SortioColors.accentBright,
          surface: SortioColors.card,
          error: SortioColors.red,
        ),
        fontFamily: SortioFonts.sans,
        splashFactory: InkSplash.splashFactory,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: SortioColors.textBody, height: 1.45),
        ),
      ),
      initialRoute: SortioRoutes.home,
      onGenerateRoute: (settings) => SortioRoutes.onGenerateRoute(settings, screens: {
        SortioRoutes.home: (context) => HomeShell(
              initialPanel: settings.arguments is StartPanel
                  ? settings.arguments! as StartPanel
                  : StartPanel.none,
            ),
      }),
    );
  }
}
