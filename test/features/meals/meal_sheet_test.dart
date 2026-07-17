import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';

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

  testApp('typing grams saves the amount and shows live kcal', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final nutrition = NutritionRepository(harness.db, foods);
    final rice = await foods.create('Rice');
    await nutrition.saveFacts(
      rice.id,
      const NutritionFacts(per100: Nutrients(kcal: 130)),
    );

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice'); // suggestion chip → picked row
    await tester.enterText(
      find.byKey(const ValueKey('amount:Rice')),
      '150',
    );
    await tester.pump();

    // Row kcal and the meal total update as the amount is typed.
    expect(find.text('~195 kcal'), findsOneWidget); // 130 × 150 / 100
    expect(find.text('Estimated total: ~195 kcal'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    final item = await harness.db.select(harness.db.mealEntryItems).getSingle();
    expect(item.amountG, 150.0);
    expect(item.quantity, isNull); // new rows never use the multiplier

    // The timeline subtitle spells the amount out.
    expect(find.textContaining('Rice 150 g'), findsOneWidget);
  });

  testApp('the meal sheet shows compact macro totals when available', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final nutrition = NutritionRepository(harness.db, foods);
    final salmon = await foods.create('Salmon');
    await nutrition.saveFacts(
      salmon.id,
      const NutritionFacts(
        per100: Nutrients(
          kcal: 208,
          proteinG: 20,
          carbsG: 0,
          fatG: 13,
          fiberG: 0,
        ),
        servingG: 150,
      ),
    );

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Salmon'); // prefills 150 g

    // 150 g of salmon: 30 g protein, 19.5 → 20 g fat.
    expect(find.text('P 30 · C 0 · F 20 · Fb 0 (g)'), findsOneWidget);
  });

  testApp('the amount prefills from the serving weight, then last use', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final nutrition = NutritionRepository(harness.db, foods);
    final pasta = await foods.create('Pasta');
    await nutrition.saveFacts(
      pasta.id,
      const NutritionFacts(per100: Nutrients(kcal: 350), servingG: 80),
    );

    // Never logged → the typical serving weight prefills the field.
    await tapQuickAdd(tester, 'Meal');
    await tester.tap(find.widgetWithText(ActionChip, 'Pasta'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount:Pasta')))
          .controller
          ?.text,
      '80',
    );
    await tester.enterText(
      find.byKey(const ValueKey('amount:Pasta')),
      '120',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    // Logged once → the last amount wins over the serving weight.
    await tapQuickAdd(tester, 'Meal');
    await tester.tap(find.widgetWithText(ActionChip, 'Pasta'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount:Pasta')))
          .controller
          ?.text,
      '120',
    );
  });

  testApp('the stepper buttons adjust the grams by ten', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice');
    await tester.tap(find.byTooltip('Increase amount'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase amount'));
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease amount'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount:Rice')))
          .controller
          ?.text,
      '10',
    );
  });

  testApp('a picked food without values offers the add-values link', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await tapQuickAdd(tester, 'Meal');
    await tapInSheet(tester, 'Rice');

    expect(find.text('—'), findsOneWidget); // no kcal figure
    await tapInSheet(tester, 'Add values');
    // The per-100g editor opened for that food.
    expect(find.text('kcal per 100 g'), findsOneWidget);
  });

  testApp('editing a historical meal keeps its legacy servings and shows '
      'their kcal', (tester, harness) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final meals = MealRepository(harness.db, foods, harness.clock.call);
    final nutrition = NutritionRepository(harness.db, foods);
    final rice = await foods.create('Rice');
    await nutrition.saveFacts(
      rice.id,
      const NutritionFacts(legacyPerServing: Nutrients(kcal: 220)),
    );
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
    // The legacy row shows its kcal (220 × 2) with an empty grams field.
    expect(find.text('~440 kcal'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount:Rice')))
          .controller
          ?.text,
      isEmpty,
    );
    await tapInSheet(tester, 'Save'); // untouched round-trip

    final item = await harness.db.select(harness.db.mealEntryItems).getSingle();
    expect(item.quantity, 2.0);
    expect(item.amountG, isNull);
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

  testApp('undoing a delete from the edit sheet keeps quantity and grams', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final meals = MealRepository(harness.db, foods, harness.clock.call);
    final rice = await foods.create('Rice');
    final pasta = await foods.create('Pasta');
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 14, 13),
      items: [
        MealItemInput.existing(foodItemId: rice.id, quantity: 2),
        MealItemInput.existing(foodItemId: pasta.id, amountG: 120),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();
    await tapInSheet(tester, 'Delete');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final items = await harness.db.select(harness.db.mealEntryItems).get();
    final byFood = {for (final i in items) i.foodItemId: i};
    expect(byFood[rice.id]?.quantity, 2.0);
    expect(byFood[rice.id]?.amountG, isNull);
    expect(byFood[pasta.id]?.amountG, 120.0);
  });
}
