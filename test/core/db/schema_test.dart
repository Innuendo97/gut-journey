import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('created schema matches the code-declared schema', () async {
    // Catches drift declarations that generate invalid or mismatched SQL,
    // and will keep validating the end state once migrations exist.
    await db.validateDatabaseSchema();
  });

  test('creates every declared table and index', () async {
    final rows = await db
        .customSelect(
          "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();

    const expectedTables = {
      'food_items',
      'food_attributes',
      'meal_entries',
      'meal_entry_items',
      'symptom_types',
      'symptom_entries',
      'bowel_entries',
      'weight_entries',
      'water_entries',
      'sleep_entries',
      'activity_entries',
      'medications',
      'medication_intakes',
      'fodmap_challenges',
    };
    expect(names, containsAll(expectedTables));

    final entryTablesWithDayIndex = expectedTables.difference({
      'food_items',
      'food_attributes',
      'meal_entry_items',
      'symptom_types',
      'medications',
      'fodmap_challenges',
    });
    for (final table in entryTablesWithDayIndex) {
      expect(names, contains('idx_${table}_local_day'));
    }
    expect(names, contains('idx_fodmap_challenges_start_day'));
  });

  test('seeds one symptom type per preset key', () async {
    final rows = await db.select(db.symptomTypes).get();
    expect(
      rows.map((r) => r.presetKey),
      containsAll(symptomPresetKeys),
    );
    expect(rows, hasLength(symptomPresetKeys.length));
    expect(rows.map((r) => r.id), everyElement(startsWith('preset-')));
  });

  test('enforces foreign keys', () async {
    await expectLater(
      db
          .into(db.foodAttributes)
          .insert(
            FoodAttributesCompanion.insert(
              id: 'attr-1',
              foodItemId: 'missing-food',
              source: 'fodmap',
              key: 'overall',
              value: 'high',
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects out-of-range values via CHECK constraints', () async {
    final now = DateTime.utc(2026, 7, 14, 12);
    await expectLater(
      db
          .into(db.bowelEntries)
          .insert(
            BowelEntriesCompanion.insert(
              id: 'bowel-1',
              bristolType: 8,
              occurredAt: now,
              localDay: '2026-07-14',
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('rejects a symptom type with both preset key and custom name', () async {
    await expectLater(
      db
          .into(db.symptomTypes)
          .insert(
            SymptomTypesCompanion.insert(
              id: 'bad-type',
              presetKey: const Value('bloating2'),
              customName: const Value('Bloating'),
              createdAt: DateTime.utc(2026),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
