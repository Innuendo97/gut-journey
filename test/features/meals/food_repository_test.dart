import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FoodRepository repo;

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    repo = FoodRepository(db, clock.call);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates foods and lists them alphabetically', () async {
    await repo.create('Rice');
    await repo.create('Banana');
    final library = await repo.watchLibrary().first;
    expect(library.map((f) => f.name), ['Banana', 'Rice']);
  });

  test('watchLibrary filters by substring', () async {
    await repo.create('Lactose-free milk');
    await repo.create('Rice');
    final results = await repo.watchLibrary(query: 'milk').first;
    expect(results.map((f) => f.name), ['Lactose-free milk']);
  });

  test('getOrCreateByName reuses existing foods case-insensitively', () async {
    final first = await repo.getOrCreateByName('Banana');
    final second = await repo.getOrCreateByName('  banana ');
    expect(second.id, first.id);
    expect(await repo.watchLibrary().first, hasLength(1));
  });

  test('suggest ranks favorites, then usage, and filters by prefix', () async {
    final rice = await repo.create('Rice');
    final riceCakes = await repo.create('Rice cakes');
    final risotto = await repo.create('Risotto');
    await repo.create('Banana');

    await repo.setFavorite(risotto.id, isFavorite: true);
    await repo.recordUsage([rice.id, rice.id], clock.now);
    await repo.recordUsage([riceCakes.id], clock.now);

    final suggestions = await repo.suggest('ri');
    expect(
      suggestions.map((f) => f.name),
      ['Risotto', 'Rice', 'Rice cakes'],
    );
  });

  test('recordUsage increments usage count and stamps last use', () async {
    final rice = await repo.create('Rice');
    await repo.recordUsage([rice.id], clock.now);
    await repo.recordUsage([rice.id], clock.now);
    final reloaded = (await repo.watchLibrary().first).single;
    expect(reloaded.usageCount, 2);
    expect(reloaded.lastUsedAt, clock.now);
  });

  test('delete refuses when the food is referenced by a meal', () async {
    final meals = MealRepository(db, repo, clock.call);
    final rice = await repo.create('Rice');
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: clock.now,
      items: [MealItemInput.existing(foodItemId: rice.id)],
    );

    expect(await repo.delete(rice.id), isFalse);
    expect(await repo.watchLibrary().first, hasLength(1));

    final unused = await repo.create('Banana');
    expect(await repo.delete(unused.id), isTrue);
  });

  test('attributes upsert per (source, key) and read back as a map', () async {
    final rice = await repo.create('Rice');
    await repo.setAttribute(
      foodItemId: rice.id,
      source: 'fodmap',
      key: 'overall',
      value: 'low',
    );
    await repo.setAttribute(
      foodItemId: rice.id,
      source: 'fodmap',
      key: 'overall',
      value: 'high',
    );
    await repo.setAttribute(
      foodItemId: rice.id,
      source: 'fodmap',
      key: 'fructan',
      value: 'low',
    );

    final attributes = await repo.getAttributes(rice.id, source: 'fodmap');
    expect(attributes, {'overall': 'high', 'fructan': 'low'});
    expect(await repo.getAttributes(rice.id, source: 'other'), isEmpty);
  });

  test(
    'watchAttributeValues maps the library live and removal clears',
    () async {
      final rice = await repo.create('Rice');
      final milk = await repo.create('Milk');
      await repo.setAttribute(
        foodItemId: milk.id,
        source: 'fodmap',
        key: 'group',
        value: 'lactose',
      );
      // A different key must not leak into the map.
      await repo.setAttribute(
        foodItemId: rice.id,
        source: 'fodmap',
        key: 'overall',
        value: 'low',
      );

      final byFood = await repo
          .watchAttributeValues(source: 'fodmap', key: 'group')
          .first;
      expect(byFood, {milk.id: 'lactose'});

      await repo.setAttribute(
        foodItemId: rice.id,
        source: 'fodmap',
        key: 'group',
        value: 'fructans',
      );
      expect(
        await repo.watchAttributeValues(source: 'fodmap', key: 'group').first,
        {milk.id: 'lactose', rice.id: 'fructans'},
      );

      await repo.removeAttribute(
        foodItemId: milk.id,
        source: 'fodmap',
        key: 'group',
      );
      expect(
        await repo.watchAttributeValues(source: 'fodmap', key: 'group').first,
        {rice.id: 'fructans'},
      );
      // Other keys survive the targeted removal.
      expect(await repo.getAttributes(rice.id, source: 'fodmap'), {
        'overall': 'low',
        'group': 'fructans',
      });
    },
  );
}
