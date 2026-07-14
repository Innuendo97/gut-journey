import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('switching language re-renders the whole app in Italian', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italiano').last);
    await tester.pumpAndSettle();

    // Tab labels and the settings screen itself are now Italian.
    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Impostazioni'), findsWidgets);
    expect(find.text('Lingua'), findsOneWidget);
  });

  testApp('changing the water goal updates the Today card', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daily water goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1500');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 1500 ml'), findsOneWidget);
  });

  testApp('custom symptom types appear in the symptom sheet', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage symptom types'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add symptom type'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Brain fog');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The custom type lands at the bottom of the list, below the fold.
    await tester.scrollUntilVisible(
      find.text('Brain fog'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Brain fog'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tapQuickAdd(tester, 'Symptom');
    expect(find.text('Brain fog'), findsOneWidget);
  });
}
