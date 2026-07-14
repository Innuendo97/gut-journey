import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('shows the empty state on a fresh day', (tester, harness) async {
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.text('0 / 2000 ml'), findsOneWidget);
  });

  testApp('water quick-add logs 250 ml instantly', (tester, harness) async {
    await tapQuickAdd(tester, 'Water');
    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();

    expect(find.text('500 / 2000 ml'), findsOneWidget);
    expect(find.text('250 ml'), findsNWidgets(2)); // two timeline rows
  });

  testApp('symptom sheet logs a preset symptom with intensity', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Symptom');
    await tapInSheet(tester, 'Bloating');
    await tapInSheet(tester, 'Severe');
    await tapInSheet(tester, 'Save');

    expect(find.text('Bloating'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
  });

  testApp('bowel sheet logs a Bristol type', (tester, harness) async {
    await tapQuickAdd(tester, 'Bowel');
    await tapInSheet(tester, 'Smooth and soft'); // Bristol 4
    await tapInSheet(tester, 'Save');

    expect(find.text('Bristol 4'), findsOneWidget);
  });

  testApp('meal sheet creates a meal with an inline-typed food', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Meal');
    await tester.enterText(find.byType(TextField).first, 'Rice');
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Add "Rice"');
    await tapInSheet(tester, 'Save');

    // Clock is pinned to midday → the guessed meal type is lunch.
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);

    final meals = await harness.db.select(harness.db.mealEntries).get();
    expect(meals.single.mealType, MealType.lunch);
    final foods = await harness.db.select(harness.db.foodItems).get();
    expect(foods.single.name, 'Rice');
  });

  testApp('weight sheet saves a measurement', (tester, harness) async {
    await tapQuickAdd(tester, 'Weight');
    await tester.enterText(find.byType(TextField).last, '70.5');
    await tapInSheet(tester, 'Save');

    expect(find.text('70.5 kg'), findsOneWidget);
  });

  testApp('swiping a timeline entry deletes it and undo restores it', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Water');
    expect(find.text('250 / 2000 ml'), findsOneWidget);

    await tester.drag(find.text('250 ml'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('0 / 2000 ml'), findsOneWidget);
    expect(find.text('Entry deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('250 / 2000 ml'), findsOneWidget);
  });

  testApp('day navigation shows yesterday and disables the future', (
    tester,
    harness,
  ) async {
    final today = LocalDay.fromDateTime(harness.clock.now);

    expect(find.text('Today'), findsWidgets);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsNothing);

    // On today, the forward arrow is disabled.
    final forward = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(forward.onPressed, isNull);
    expect(today, LocalDay('2026-07-14'));
  });
}
