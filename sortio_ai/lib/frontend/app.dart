// ============================================================================
// Sortio AI — frontend/app.dart
//
// App root: the MaterialApp, wired to the backend router and theme. Listens
// to the theme bus so the Dark mode setting swaps the ThemeData (status bar,
// cursor, splash colors) along with the design tokens.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/controller.dart';
import '../backend/design_tokens.dart';
import '../backend/routes.dart';
import 'home_shell.dart';

class SortioApp extends StatelessWidget {
  const SortioApp({super.key});

  /// Keeps the system bars readable: light icons on the dark theme, dark
  /// icons on the light one. Re-applied on every theme switch.
  void _applySystemChrome(bool dark) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: SortioColors.page,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SortioThemeBus.instance,
      builder: (context, _) {
        final dark = SortioColors.isDark;
        _applySystemChrome(dark);
        return MaterialApp(
          title: 'Sortio AI — Chat',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: SortioColors.page,
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: SortioColors.accent,
                    secondary: SortioColors.accentBright,
                    surface: SortioColors.card,
                    error: SortioColors.red,
                  )
                : ColorScheme.light(
                    primary: SortioColors.accent,
                    secondary: SortioColors.accentBright,
                    surface: SortioColors.card,
                    error: SortioColors.red,
                  ),
            fontFamily: SortioFonts.sans,
            splashFactory: InkSplash.splashFactory,
            textTheme: TextTheme(
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
      },
    );
  }
}
