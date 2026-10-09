// Verifies that the Sortio AI app boots, renders and navigates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortio_ai/frontend/app.dart';

void main() {
  testWidgets('chat screen renders the header, feed and composer', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sortio AI'), findsOneWidget);
    expect(find.text('How can I help you sort your files?'), findsNothing);
    expect(
      find.text('Ask Sortio to find or tidy files…'),
      findsOneWidget,
    );
  });

  testWidgets('settings tab opens Settings and the dark mode toggle switches palettes', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // The screen title plus the active tab's label in the nav bar.
    expect(find.text('Settings'), findsNWidgets(2));
    expect(find.text('FOLDER SANDBOX'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('DANGER ZONE'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    // Dark mode off -> the light palette repaints the app.
    await tester.tap(find.byKey(const ValueKey('dark-mode-switch')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFF4F6FB),
    );

    // Back on -> the original dark palette.
    await tester.tap(find.byKey(const ValueKey('dark-mode-switch')));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF0B0F19),
    );
  });

  testWidgets('navigation bar switches between tabs and the + opens chat', (tester) async {
    await tester.pumpWidget(const SortioApp());
    await tester.pump(const Duration(milliseconds: 600));

    // Home tab
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Tidy Downloads'), findsOneWidget);
    expect(find.text('RECENT CHATS'), findsOneWidget);

    // History tab — the chat history
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.text('Your conversations with Sortio.'), findsOneWidget);
    expect(find.text('Meralco bill & downloads'), findsOneWidget);

    // Opening a chat reopens that conversation in the chat screen
    await tester.tap(find.text('March receipts for taxes'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.textContaining('Found 4 receipts'), findsOneWidget);
    expect(
      find.text('Ask Sortio to find or tidy files…'),
      findsOneWidget,
    );

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
