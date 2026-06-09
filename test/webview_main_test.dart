import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:webview_cef_example/main.dart';

void main() {
  testWidgets('Verify the button changes text upon click', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify initial button text
    final initialTextFinder = find.text('Click me');
    expect(initialTextFinder, findsOneWidget);

    // Tap the button which should change its text
    await tester.tap(initialTextFinder);
    await tester.pump();  // Rebuild the widget after the state has changed

    // Verify the button's text has changed after being clicked
    expect(find.text('Clicked!'), findsOneWidget);
  });
}
