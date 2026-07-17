import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> addActivity(WidgetTester tester, String name) async {
  await tapQuickAdd(tester, 'Activity');
  await tester.enterText(find.byType(TextField).first, name);
  await tapInSheet(tester, 'Save');
}

void main() {
  testApp('deleting an activity from its edit sheet, with undo', (
    tester,
    harness,
  ) async {
    await addActivity(tester, 'Walk');
    expect(find.text('Walk'), findsOneWidget);

    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Delete');

    expect(find.text('Walk'), findsNothing);
    expect(find.text('Entry deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsOneWidget);
  });

  testApp('deleting an activity by swiping its timeline row', (
    tester,
    harness,
  ) async {
    await addActivity(tester, 'Yoga');

    await tester.drag(find.text('Yoga'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); // confirm the swipe
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsNothing);
    expect(find.text('Entry deleted'), findsOneWidget);
  });

  testApp('deleting a meal from its edit sheet and undoing restores foods', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Meal');
    await tester.enterText(find.byType(TextField).first, 'Rice');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Save');
    expect(find.text('Rice'), findsOneWidget);

    // The add-values nudge for the new inline food shows once its db
    // lookups resolve (pump-driven under fake async); wait for it and
    // clear it, so the delete snackbar below is neither queued behind it
    // nor covered by it (root-messenger snackbars float above sheets).
    for (var i = 0; i < 50 && find.byType(SnackBar).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('"Rice" has no nutrition values yet'),
      findsOneWidget,
    );
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Delete');
    expect(find.text('Rice'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testApp('the Delete button only appears when editing an existing entry', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Weight');
    expect(find.text('Delete'), findsNothing);
  });
}
