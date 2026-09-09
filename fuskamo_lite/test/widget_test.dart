import 'package:flutter_test/flutter_test.dart';
import 'package:fuskamo/widgets/filter_pill.dart';
import 'package:flutter/material.dart';

// Minimal smoke test — expand real coverage in Phase 2 (see docs/testing.md).
void main() {
  testWidgets('FilterPill renders its label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FilterPill(label: 'All', active: true, onTap: () {}),
        ),
      ),
    );
    expect(find.text('All'), findsOneWidget);
  });
}
