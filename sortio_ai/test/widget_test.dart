// Verifies that the converted Sortio AI chat screen boots and renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortio_ai/frontend/app.dart';

void main() {
  testWidgets('chat screen renders the header, feed and composer', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sortio AI'), findsOneWidget);
    expect(find.text('Offline Mode'), findsOneWidget);
    expect(find.text('Today · on-device session'), findsOneWidget);
    expect(
      find.text('Ask Sortio to find or tidy files…'),
      findsOneWidget,
    );
  });

  testWidgets('sessions drawer opens from the menu button', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Savings Summary'), findsOneWidget);
  });

  testWidgets('privacy sheet opens from the settings button', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Privacy Command Center'), findsOneWidget);
    expect(find.text('FOLDER SANDBOX'), findsOneWidget);
    expect(find.text('DANGER ZONE'), findsOneWidget);
  });
}
