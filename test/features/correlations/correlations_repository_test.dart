import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/correlations/data/correlations_repository.dart';
import 'package:gut_journey/features/correlations/domain/correlation_models.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MealRepository meals;
  late SymptomRepository symptoms;
  late CorrelationsRepository repo;

  final range = DateRange(LocalDay('2026-07-08'), LocalDay('2026-07-14'));
  const window = Duration(hours: 8);

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    meals = MealRepository(db, FoodRepository(db, clock.call), clock.call);
    symptoms = SymptomRepository(db, clock.call);
    repo = CorrelationsRepository(meals: meals, symptoms: symptoms);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> lunch(int day, String food) => meals.createMeal(
    type: MealType.lunch,
    occurredAt: DateTime(2026, 7, day, 13),
    items: [MealItemInput.newFood(name: food)],
  );

  Future<void> bloating(int day, int hour) => symptoms.addEntry(
    symptomTypeId: symptomPresetId('bloating'),
    intensity: 5,
    occurredAt: DateTime(2026, 7, day, hour),
  );

  test('emits associations computed from repository data', () async {
    // Milk on 4 days, rice on 3; bloating after 2 milk lunches.
    for (final day in [8, 9, 10, 11]) {
      await lunch(day, 'Milk');
    }
    for (final day in [12, 13, 14]) {
      await lunch(day, 'Rice');
    }
    await bloating(8, 15);
    await bloating(9, 15);
    await bloating(12, 6); // before lunch: eligible event, no co-occurrence

    final result = await repo
        .watchAssociations(range: range, window: window)
        .first;

    expect(result.analyzedMeals, 7);
    expect(result.analyzedSymptomEvents, 3);
    final milk = result.associations.single;
    expect(milk.foodName, 'Milk');
    expect(milk.symptomTypeId, symptomPresetId('bloating'));
    expect(milk.exposedWithSymptom, 2);
    expect(milk.baselineWithSymptom, 0);
    expect(milk.lift, isNull);
  });

  test('re-emits when a new diary entry changes the picture', () async {
    for (final day in [8, 9, 10, 11]) {
      await lunch(day, 'Milk');
    }
    for (final day in [12, 13, 14]) {
      await lunch(day, 'Rice');
    }
    await bloating(8, 15);
    await bloating(9, 15);

    // The combined stream is single-subscription: iterate it to observe the
    // live re-emission triggered by the write below.
    final emissions = StreamIterator(
      repo.watchAssociations(range: range, window: window),
    );
    // Two eligible events exist but only after the third is added does the
    // bloating type clear minSymptomEvents.
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current.associations, isEmpty);

    await bloating(10, 15);

    expect(await emissions.moveNext(), isTrue);
    final milk = emissions.current.associations.single;
    expect(milk.exposedWithSymptom, 3);
    expect(milk.strength, CorrelationStrength.strong);
    await emissions.cancel();
  });

  test('counts a symptom the morning after the period ends', () async {
    for (final day in [8, 9, 10]) {
      await lunch(day, 'Milk');
    }
    for (final day in [12, 13, 14]) {
      await lunch(day, 'Rice');
    }
    await bloating(8, 15);
    await bloating(9, 15);
    // 20:00 on the 14th is past none of the boundaries; the interesting one:
    // 14 July lunch at 13:00 + 8h = 21:00 same day, but a meal on the last
    // evening would reach into the 15th. Log the last lunch late instead.
    await meals.createMeal(
      type: MealType.dinner,
      occurredAt: DateTime(2026, 7, 14, 21),
      items: const [MealItemInput.newFood(name: 'Milk')],
    );
    await bloating(15, 2); // 02:00 next day, within the dinner's window

    final result = await repo
        .watchAssociations(range: range, window: window)
        .first;

    final milk = result.associations.single;
    expect(milk.foodName, 'Milk');
    // 8, 9 and the late dinner on the 14th.
    expect(milk.exposedWithSymptom, 3);
  });
}
