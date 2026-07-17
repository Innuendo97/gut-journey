import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';

import '../../generated/schema.dart';
import '../../generated/schema_v1.dart' as v1;

/// Every schema bump gets its scenario here: local-first apps must never
/// eat user data, so each migration is validated end-state AND replayed
/// over a database that already holds diary entries.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates an empty v1 database to v2', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 2);
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
}
