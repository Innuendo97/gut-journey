import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> addActivity(WidgetTester tester, String name) async {
  await tapQuickAdd(tester, 'Activity');
  await tester.enterText(find.byType(TextField).first, name);
  await tapInSheet(tester, 'Save');
}

Future<void> deleteFromEditSheet(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tapInSheet(tester, 'Delete');
}

void main() {
  testApp('the delete snackbar auto-dismisses after its duration', (
    tester,
    harness,
  ) async {
    await addActivity(tester, 'Walk');
    await deleteFromEditSheet(tester, 'Walk');

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Entry deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Entry deleted'), findsNothing);
  });

  testApp('a second delete replaces the first snackbar instead of queueing', (
    tester,
    harness,
  ) async {
    await addActivity(tester, 'Walk');
    await addActivity(tester, 'Yoga');

    await deleteFromEditSheet(tester, 'Walk');
    expect(find.byType(SnackBar), findsOneWidget);

    // Second delete via swipe while the first snackbar is still up (the
    // floating snackbar sits over the sheet's own Delete button, so the
    // timeline swipe is the natural second gesture here).
    await tester.drag(find.text('Yoga'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); // confirm the swipe
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    // And the replacement dismisses on its own too — nothing stays queued.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testApp('the delete snackbar floats with the inline styling', (
    tester,
    harness,
  ) async {
    await addActivity(tester, 'Walk');
    await deleteFromEditSheet(tester, 'Walk');

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.margin, const EdgeInsets.all(16));
  });
}
