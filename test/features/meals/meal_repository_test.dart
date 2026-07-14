import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FoodRepository foods;
  late MealRepository repo;

  // A fixed local moment keeps day-bucketing assertions deterministic.
  final lunchTime = DateTime(2026, 7, 14, 13);
  final day = LocalDay('2026-07-14');

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    foods = FoodRepository(db, clock.call);
    repo = MealRepository(db, foods, clock.call);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates a meal mixing existing and inline-typed foods', () async {
    final rice = await foods.create('Rice');
    await repo.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: [
        MealItemInput.existing(
          foodItemId: rice.id,
          portionDescription: '1 cup',
        ),
        const MealItemInput.newFood(name: 'Grilled chicken'),
      ],
    );

    final meals = await repo.watchByDay(day).first;
    final meal = meals.single;
    expect(meal.type, MealType.lunch);
    expect(
      meal.items.map((i) => i.food.name).toSet(),
      {'Rice', 'Grilled chicken'},
    );
    expect(
      meal.items.firstWhere((i) => i.food.name == 'Rice').portionDescription,
      '1 cup',
    );

    // The inline food joined the library and both got a usage bump.
    final library = await foods.watchLibrary().first;
    expect(library, hasLength(2));
    expect(library.map((f) => f.usageCount), everyElement(1));
  });

  test('buckets meals on the local day they occurred', () async {
    await repo.createMeal(
      type: MealType.snack,
      occurredAt: DateTime(2026, 7, 15, 0, 30), // just past local midnight
      items: const [MealItemInput.newFood(name: 'Crackers')],
    );
    await repo.createMeal(
      type: MealType.dinner,
      occurredAt: DateTime(2026, 7, 14, 23, 30),
      items: const [MealItemInput.newFood(name: 'Soup')],
    );

    final on14th = await repo.watchByDay(day).first;
    final on15th = await repo.watchByDay(LocalDay('2026-07-15')).first;
    expect(on14th.single.type, MealType.dinner);
    expect(on15th.single.type, MealType.snack);
  });

  test('orders a day chronologically and keeps foodless meals', () async {
    await repo.createMeal(
      type: MealType.dinner,
      occurredAt: DateTime(2026, 7, 14, 20),
      items: const [],
      notes: 'Ate out, unsure what was in it',
    );
    await repo.createMeal(
      type: MealType.breakfast,
      occurredAt: DateTime(2026, 7, 14, 8),
      items: const [MealItemInput.newFood(name: 'Oats')],
    );

    final meals = await repo.watchByDay(day).first;
    expect(meals.map((m) => m.type), [MealType.breakfast, MealType.dinner]);
    expect(meals.last.items, isEmpty);
    expect(meals.last.notes, 'Ate out, unsure what was in it');
  });

  test(
    'updateMeal replaces foods and can move the meal to another day',
    () async {
      final id = await repo.createMeal(
        type: MealType.lunch,
        occurredAt: lunchTime,
        items: const [MealItemInput.newFood(name: 'Rice')],
      );

      await repo.updateMeal(
        id: id,
        type: MealType.dinner,
        occurredAt: DateTime(2026, 7, 15, 20),
        items: const [MealItemInput.newFood(name: 'Pasta')],
        notes: 'moved',
      );

      expect(await repo.watchByDay(day).first, isEmpty);
      final moved =
          (await repo.watchByDay(LocalDay('2026-07-15')).first).single;
      expect(moved.type, MealType.dinner);
      expect(moved.items.map((i) => i.food.name), ['Pasta']);
      expect(moved.notes, 'moved');
    },
  );

  test('deleteMeal removes its items but not the library foods', () async {
    final id = await repo.createMeal(
      type: MealType.lunch,
      occurredAt: lunchTime,
      items: const [MealItemInput.newFood(name: 'Rice')],
    );

    await repo.deleteMeal(id);

    expect(await repo.watchByDay(day).first, isEmpty);
    expect(await db.select(db.mealEntryItems).get(), isEmpty);
    expect(await foods.watchLibrary().first, hasLength(1));
  });
}
