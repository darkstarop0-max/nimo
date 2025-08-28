// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storage_cleaner_app/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(initialRoute: '/home'));

    // Verify that the app title appears
    expect(find.text('Storage Cleaner'), findsOneWidget);

    // Since we start with the home route, we should be on the home screen
    // We can verify this by checking for elements specific to the home screen
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
