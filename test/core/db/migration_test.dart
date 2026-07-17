import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';

import '../../generated/schema.dart';
import '../../generated/schema_v1.dart' as v1;
import '../../generated/schema_v2.dart' as v2;

/// Every schema bump gets its scenario here: local-first apps must never
/// eat user data, so each migration is validated end-state AND replayed
/// over a database that already holds diary entries.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates an empty v1 database to the latest version', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('migrates an empty v2 database to v3', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test('v1 diary data survives the migration to v2', () async {
    const stamp = '2026-07-10T08:00:00.000Z';
    final schema = await verifier.schemaAt(1);

    final before = v1.DatabaseAtV1(schema.newConnection());
    await before
        .into(before.foodItems)
        .insert(
          v1.FoodItemsCompanion.insert(
            id: 'food-1',
            createdAt: stamp,
            updatedAt: stamp,
            name: 'Milk',
          ),
        );
    await before
        .into(before.mealEntries)
        .insert(
          v1.MealEntriesCompanion.insert(
            id: 'meal-1',
            createdAt: stamp,
            updatedAt: stamp,
            occurredAt: stamp,
            localDay: '2026-07-10',
            mealType: 'breakfast',
          ),
        );
    await before
        .into(before.mealEntryItems)
        .insert(
          v1.MealEntryItemsCompanion.insert(
            id: 'item-1',
            mealEntryId: 'meal-1',
            foodItemId: 'food-1',
          ),
        );
    await before
        .into(before.symptomTypes)
        .insert(
          v1.SymptomTypesCompanion.insert(
            id: 'preset-bloating',
            presetKey: const Value('bloating'),
            createdAt: stamp,
          ),
        );
    await before
        .into(before.symptomEntries)
        .insert(
          v1.SymptomEntriesCompanion.insert(
            id: 'sym-1',
            createdAt: stamp,
            updatedAt: stamp,
            occurredAt: stamp,
            localDay: '2026-07-10',
            symptomTypeId: 'preset-bloating',
            intensity: 5,
          ),
        );
    await before.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final food = await db.select(db.foodItems).getSingle();
    expect(food.name, 'Milk');
    final item = await db.select(db.mealEntryItems).getSingle();
    expect(item.mealEntryId, 'meal-1');
    final symptom = await db.select(db.symptomEntries).getSingle();
    expect(symptom.intensity, 5);
    // The new table arrives empty and writable.
    expect(await db.select(db.fodmapChallenges).get(), isEmpty);
  });

  test('v2 diary data survives the migration to v3', () async {
    const stamp = '2026-07-15T08:00:00.000Z';
    final schema = await verifier.schemaAt(2);

    final before = v2.DatabaseAtV2(schema.newConnection());
    await before
        .into(before.foodItems)
        .insert(
          v2.FoodItemsCompanion.insert(
            id: 'food-1',
            createdAt: stamp,
            updatedAt: stamp,
            name: 'Rice',
          ),
        );
    await before
        .into(before.foodAttributes)
        .insert(
          v2.FoodAttributesCompanion.insert(
            id: 'attr-1',
            foodItemId: 'food-1',
            source: 'fodmap',
            key: 'group',
            value: 'fructans',
          ),
        );
    await before
        .into(before.mealEntries)
        .insert(
          v2.MealEntriesCompanion.insert(
            id: 'meal-1',
            createdAt: stamp,
            updatedAt: stamp,
            occurredAt: stamp,
            localDay: '2026-07-15',
            mealType: 'lunch',
          ),
        );
    await before
        .into(before.mealEntryItems)
        .insert(
          v2.MealEntryItemsCompanion.insert(
            id: 'item-1',
            mealEntryId: 'meal-1',
            foodItemId: 'food-1',
            portionDescription: const Value('small bowl'),
          ),
        );
    await before.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final attribute = await db.select(db.foodAttributes).getSingle();
    expect(attribute.value, 'fructans');
    final item = await db.select(db.mealEntryItems).getSingle();
    expect(item.portionDescription, 'small bowl');
    // The new column arrives null (meaning one serving) and writable.
    expect(item.quantity, isNull);
    await (db.update(db.mealEntryItems)..where((t) => t.id.equals('item-1')))
        .write(const MealEntryItemsCompanion(quantity: Value(2)));
    final updated = await db.select(db.mealEntryItems).getSingle();
    expect(updated.quantity, 2.0);
  });
}
