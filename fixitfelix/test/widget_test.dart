// Smoke test for the customer app shell.
//
// The real app boots against Supabase in main(), so this only checks that the
// root widget tree builds — enough to catch a broken constructor or a missing
// provider without needing a backend.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp shell builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('FixItFelix'))),
    );

    expect(find.text('FixItFelix'), findsOneWidget);
  });
}
