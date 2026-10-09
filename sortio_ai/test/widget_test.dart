// Verifies that the Sortio AI app boots, renders and navigates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortio_ai/frontend/app.dart';

void main() {
  testWidgets('chat screen renders the header, feed and composer', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sortio AI'), findsOneWidget);
    expect(find.text('Today · on-device session'), findsOneWidget);
    expect(
      find.text('Ask Sortio to find or tidy files…'),
      findsOneWidget,
    );
  });

  testWidgets('settings tab opens the Privacy Command Center', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Privacy Command Center'), findsOneWidget);
    expect(find.text('FOLDER SANDBOX'), findsOneWidget);
    expect(find.text('DANGER ZONE'), findsOneWidget);
  });

  testWidgets('navigation bar switches between tabs and the + opens chat', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    // Home tab
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Tidy Downloads'), findsOneWidget);
    expect(find.text('RECENT ACTIVITY'), findsOneWidget);

    // History tab
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Every action, logged on this device only.'), findsOneWidget);

    // Files tab
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('IMG_2043.pdf'), findsOneWidget);

    // Documents is disallowed -> its section shows a "Locked" placeholder.
    await tester.scrollUntilVisible(
      find.text('Locked'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Locked'), findsOneWidget);

    // Back to chat via the floating +
    await tester.tap(find.bySemanticsLabel('Open Sortio chat'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Ask Sortio to find or tidy files…'), findsOneWidget);
  });
}
