import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('shows empty-state hints when nothing is logged', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('30 days'), findsOneWidget);
    expect(find.byTooltip('Export PDF report'), findsOneWidget);
    expect(
      find.text('Not enough data yet — log a few days to see this.'),
      findsWidgets,
    );
  });

  testApp('renders sections once data exists', (tester, harness) async {
    await tapQuickAdd(tester, 'Water');
    await tapQuickAdd(tester, 'Symptom');
    await tapInSheet(tester, 'Bloating');
    await tapInSheet(tester, 'Save');

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Symptom frequency'), findsOneWidget);
    // The frequency row lists the logged symptom with its count.
    expect(find.text('Bloating'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Water (ml)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Water (ml)'), findsOneWidget);

    // Switching period keeps the screen alive.
    await tester.scrollUntilVisible(
      find.text('7 days'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.text('Symptom intensity'), findsOneWidget);
  });
}
