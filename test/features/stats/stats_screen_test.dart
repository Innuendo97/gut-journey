import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';

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

    // The observed-patterns card sits on top; the sections scroll below it.
    await tester.scrollUntilVisible(
      find.text('Symptom frequency'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

  testApp('the kcal section renders estimates with their disclaimer note', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final meals = MealRepository(harness.db, foods, harness.clock.call);
    final rice = await foods.create('Rice');
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionKcalKey,
      value: '200',
    );
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 13, 13),
      items: [MealItemInput.existing(foodItemId: rice.id)],
    );

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Energy (kcal, estimated)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Energy (kcal, estimated)'), findsOneWidget);
    // No goal set → the annotation restates that these are estimates
    // instead of drawing a target line.
    expect(find.textContaining('Estimates from your own'), findsOneWidget);
  });
}
