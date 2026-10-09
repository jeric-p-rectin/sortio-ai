// ============================================================================
// Sortio AI — backend/routes.dart
//
// Named routes for the app. Screens themselves live in `frontend/`; the
// router here only maps names -> builders + transitions.
// ============================================================================

import 'package:flutter/material.dart';

import 'animations.dart';

abstract final class SortioRoutes {
  /// The app entry: the navigation shell (bottom bar + tab screens).
  static const String home = '/';

  /// Called by MaterialApp's `onGenerateRoute`. The screen map is supplied by
  /// the frontend so backend stays free of widget-screen imports.
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required Map<String, WidgetBuilder> screens,
  }) {
    final builder = screens[settings.name] ?? screens[SortioRoutes.home]!;
    return FadeThroughRoute<void>(settings: settings, builder: builder);
  }
}
