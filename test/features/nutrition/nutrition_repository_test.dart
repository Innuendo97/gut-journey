import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FoodRepository foods;
  late MealRepository meals;
  late NutritionRepository repo;

  final day = LocalDay('2026-07-14');
  final lunchTime = DateTime(2026, 7, 14, 13);

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    foods = FoodRepository(db, clock.call);
    meals = MealRepository(db, foods, clock.call);
    repo = NutritionRepository(db, foods);
  });

  tearDown(() async {
    await db.close();
  });

  test('facts round-trip through the attribute table', () async {
    final rice = await foods.create('Rice');
    const facts = NutritionFacts(
      kcalPerServing: 220,
      servingDescription: 'one bowl',
      proteinG: 4.5,
      carbsG: 45,
      fatG: 0.5,
      fiberG: 1.2,
    );

    await repo.saveFacts(rice.id, facts);

    expect(await repo.getFacts(rice.id), facts);
  });

  test('clearing a field on save removes only that attribute row', () async {
    final rice = await foods.create('Rice');
    await repo.saveFacts(
      rice.id,
      const NutritionFacts(kcalPerServing: 220, proteinG: 4.5),
    );

    await repo.saveFacts(rice.id, const NutritionFacts(proteinG: 4.5));

    final stored = await foods.getAttributes(
      rice.id,
      source: nutritionAttributeSource,
    );
    expect(stored, {nutritionProteinKey: '4.5'});
    expect(
      await repo.getFacts(rice.id),
      const NutritionFacts(proteinG: 4.5),
    );
  });

  test('unparseable stored values surface as null facts', () async {
    final rice = await foods.create('Rice');
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionKcalKey,
      value: 'abc',
    );

    final facts = await repo.getFacts(rice.id);
    expect(facts.kcalPerServing, isNull);
    expect(await repo.watchKcalByFood().first, isEmpty);
  });

  test('sums kcal × servings across a day, null quantity as one', () async {
    final rice = await foods.create('Rice');
    final salmon = await foods.create('Salmon');
    final water = await foods.create('Sparkling water'); // no kcal estimate
    await repo.saveFacts(rice.id, const NutritionFacts(kcalPerServing: 200));
    await repo.saveFacts(salmon.id, const NutritionFacts(kcalPerServing: 280));

    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: [
        MealItemInput.existing(foodItemId: rice.id, quantity: 2),
        MealItemInput.existing(foodItemId: salmon.id), // null → 1 serving
        MealItemInput.existing(foodItemId: water.id, quantity: 3),
      ],
    );
    await meals.createMeal(
      type: MealType.snack,
      occurredAt: DateTime(2026, 7, 14, 17),
      items: [
        MealItemInput.existing(foodItemId: rice.id, quantity: 0.5),
      ],
    );

    // 2×200 + 1×280 + 0.5×200 — the water has no estimate and is excluded.
    expect(await repo.watchDayKcal(day).first, 780);
  });

  test('days without kcal-bearing items emit no value', () async {
    final water = await foods.create('Sparkling water');
    await meals.createMeal(
      type: MealType.drink,
      occurredAt: lunchTime,
      items: [MealItemInput.existing(foodItemId: water.id)],
    );

    expect(await repo.watchDayKcal(day).first, isNull);
    expect(
      await repo.watchKcalDaily(DateRange(day, day)).first,
      isEmpty,
    );
  });

  test('an unparseable kcal value contributes zero, not an error', () async {
    final rice = await foods.create('Rice');
    final salmon = await foods.create('Salmon');
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionKcalKey,
      value: 'abc', // CAST(abc AS REAL) → 0 in SQLite
    );
    await repo.saveFacts(salmon.id, const NutritionFacts(kcalPerServing: 280));

    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: [
        MealItemInput.existing(foodItemId: rice.id),
        MealItemInput.existing(foodItemId: salmon.id),
      ],
    );

    expect(await repo.watchDayKcal(day).first, 280);
  });

  test('groups by day in chronological order over a range', () async {
    final rice = await foods.create('Rice');
    await repo.saveFacts(rice.id, const NutritionFacts(kcalPerServing: 200));

    await meals.createMeal(
      type: MealType.dinner,
      occurredAt: DateTime(2026, 7, 13, 20),
      items: [MealItemInput.existing(foodItemId: rice.id, quantity: 2)],
    );
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: [MealItemInput.existing(foodItemId: rice.id)],
    );
    // Outside the queried range.
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 10, 13),
      items: [MealItemInput.existing(foodItemId: rice.id)],
    );

    final range = DateRange(LocalDay('2026-07-13'), LocalDay('2026-07-14'));
    expect(await repo.watchKcalDaily(range).first, [
      DailyValue(LocalDay('2026-07-13'), 400),
      DailyValue(LocalDay('2026-07-14'), 200),
    ]);
  });

  test('day total re-emits when a kcal estimate is edited', () async {
    final rice = await foods.create('Rice');
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: [MealItemInput.existing(foodItemId: rice.id, quantity: 2)],
    );

    final totals = StreamIterator(repo.watchDayKcal(day));
    expect(await totals.moveNext(), isTrue);
    expect(totals.current, isNull); // logged food, but no estimate yet

    await repo.saveFacts(rice.id, const NutritionFacts(kcalPerServing: 200));

    expect(await totals.moveNext(), isTrue);
    expect(totals.current, 400); // counted retroactively
    await totals.cancel();
  });
}
