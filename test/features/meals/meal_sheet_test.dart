import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
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

  testApp('tapping a picked chip cycles the servings that get saved', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice'); // suggestion chip → picked at ×1
    await tapInSheet(tester, 'Rice'); // picked chip → ×2
    expect(find.text('Rice ×2'), findsOneWidget);
    await tapInSheet(tester, 'Save');

    final items = await harness.db.select(harness.db.mealEntryItems).get();
    expect(items.single.quantity, 2.0);
  });

  testApp('the servings cycle reaches ×½ and wraps back to one', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice');
    await tapInSheet(tester, 'Rice');
    await tapInSheet(tester, 'Rice ×2');
    expect(find.text('Rice ×½'), findsOneWidget);

    // One more tap wraps to a single serving — stored as null, the same
    // meaning as every pre-existing item.
    await tapInSheet(tester, 'Rice ×½');
    expect(find.text('Rice'), findsOneWidget);
    await tapInSheet(tester, 'Save');

    final items = await harness.db.select(harness.db.mealEntryItems).get();
    expect(items.single.quantity, isNull);
  });

  testApp('editing a meal keeps its quantity and portion description', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final meals = MealRepository(harness.db, foods, harness.clock.call);
    final rice = await foods.create('Rice');
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 14, 13),
      items: [
        MealItemInput.existing(
          foodItemId: rice.id,
          portionDescription: '1 cup',
          quantity: 2,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch')); // timeline row → edit sheet
    await tester.pumpAndSettle();
    expect(find.text('Rice ×2'), findsOneWidget);
    await tapInSheet(tester, 'Save'); // untouched round-trip

    final item = await harness.db.select(harness.db.mealEntryItems).getSingle();
    expect(item.quantity, 2.0);
    // Regression: the edit path used to drop the portion description.
    expect(item.portionDescription, '1 cup');
  });

  testApp('a new inline food without values triggers the add-values nudge', (
    tester,
    harness,
  ) async {
    await tapQuickAdd(tester, 'Meal');
    await tester.enterText(find.byType(TextField).first, 'Seitan burger');
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Add "Seitan burger"');
    await tapInSheet(tester, 'Save');

    expect(
      find.text('"Seitan burger" has no nutrition values yet'),
      findsOneWidget,
    );

    await tester.tap(find.text('Add values'));
    await tester.pumpAndSettle();
    // The nutrition editor opened for that food; saving a value works.
    expect(find.text('Seitan burger'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, 'kcal per 100 g'),
      '320',
    );
    // Unfocus so the scroll view stops chasing the caret at the top and
    // the Save button can be scrolled into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    expect(rows.single.value, '320.0');
  });

  testApp('foods that already have values do not trigger the nudge', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final rice = await foods.create('Rice');
    await foods.setAttribute(
      foodItemId: rice.id,
      source: 'nutrition',
      key: 'kcal_per_serving',
      value: '200',
    );

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice'); // existing suggestion, not inline
    await tapInSheet(tester, 'Save');

    expect(find.textContaining('no nutrition values'), findsNothing);
  });

  testApp('undoing a delete from the edit sheet keeps the quantity', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final meals = MealRepository(harness.db, foods, harness.clock.call);
    final rice = await foods.create('Rice');
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 14, 13),
      items: [MealItemInput.existing(foodItemId: rice.id, quantity: 2)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Delete');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final item = await harness.db.select(harness.db.mealEntryItems).getSingle();
    expect(item.quantity, 2.0);
  });
}
