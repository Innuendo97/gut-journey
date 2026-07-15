import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp(
    'Italian meal-type chips show full labels on a narrow phone',
    localeTag: 'it',
    (tester, harness) async {
      // ~320 logical px wide — the width that used to ellipsize "Colazione".
      tester.view.physicalSize = const Size(640, 1440);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      await tapQuickAdd(tester, 'Pasto');
      // Full labels, no ellipsis; a RenderFlex overflow would fail the test
      // on its own.
      for (final label in const [
        'Colazione',
        'Pranzo',
        'Cena',
        'Spuntino',
        'Bevanda',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tapInSheet(tester, 'Colazione');
      await tapInSheet(tester, 'Salva');
      expect(find.text('Colazione'), findsOneWidget); // timeline row title
    },
  );

  testApp('tapping a meal-type chip drives what gets saved', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Meal');
    // FixedClock is midday, so the pre-selected guess is lunch — picking
    // dinner is a real state change.
    await tapInSheet(tester, 'Dinner');
    await tapInSheet(tester, 'Save');

    final meals = await harness.db.select(harness.db.mealEntries).get();
    expect(meals.single.mealType, MealType.dinner);
    expect(find.text('Dinner'), findsOneWidget);
  });
}
