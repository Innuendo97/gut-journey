import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/backup/data/backup_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/test_db.dart';

/// One row in every table, exercising enums, converters, nullables and all
/// the foreign-key relationships.
Future<void> seedFullDataset(AppDatabase db) async {
  final now = DateTime.utc(2026, 7, 14, 12);
  const day = '2026-07-14';
  await db.batch((b) {
    b
      ..insert(
        db.foodItems,
        FoodItemsCompanion.insert(
          id: 'food-1',
          name: 'Oats',
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.foodAttributes,
        FoodAttributesCompanion.insert(
          id: 'attr-1',
          foodItemId: 'food-1',
          source: 'fodmap',
          key: 'overall',
          value: 'low',
        ),
      )
      ..insert(
        db.symptomTypes,
        SymptomTypesCompanion.insert(
          id: 'type-custom',
          customName: const Value('Brain fog'),
          createdAt: now,
        ),
      )
      ..insert(
        db.medications,
        MedicationsCompanion.insert(
          id: 'med-1',
          name: 'Peppermint oil',
          scheduleType: ScheduleType.daily,
          scheduledTimes: const Value(['08:00']),
          startDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.mealEntries,
        MealEntriesCompanion.insert(
          id: 'meal-1',
          mealType: MealType.breakfast,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.mealEntryItems,
        MealEntryItemsCompanion.insert(
          id: 'item-1',
          mealEntryId: 'meal-1',
          foodItemId: 'food-1',
          portionDescription: const Value('a bowl'),
        ),
      )
      ..insert(
        db.symptomEntries,
        SymptomEntriesCompanion.insert(
          id: 'sym-1',
          symptomTypeId: symptomPresetId(symptomPresetKeys.first),
          intensity: 5,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.bowelEntries,
        BowelEntriesCompanion.insert(
          id: 'bowel-1',
          bristolType: 4,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.weightEntries,
        WeightEntriesCompanion.insert(
          id: 'weight-1',
          weightKg: 70.5,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.waterEntries,
        WaterEntriesCompanion.insert(
          id: 'water-1',
          amountMl: 250,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.sleepEntries,
        SleepEntriesCompanion.insert(
          id: 'sleep-1',
          localDay: day,
          durationMinutes: 480,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.activityEntries,
        ActivityEntriesCompanion.insert(
          id: 'act-1',
          activityName: 'Walk',
          durationMinutes: 30,
          effort: Effort.light,
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      )
      ..insert(
        db.medicationIntakes,
        MedicationIntakesCompanion.insert(
          id: 'intake-1',
          medicationId: 'med-1',
          status: IntakeStatus.taken,
          scheduledTime: const Value('08:00'),
          occurredAt: now,
          localDay: day,
          createdAt: now,
          updatedAt: now,
        ),
      );
  });
}

Future<int> countRows(AppDatabase db, String tableName) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM "$tableName"')
      .getSingle();
  return row.read<int>('c');
}

void main() {
  // These tests legitimately hold several AppDatabase instances at once
  // (source, target and the backup file being migrated), each with its own
  // executor — drift's corruption warning does not apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FixedClock clock;
  late BackupRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    repo = BackupRepository(db, clock.call);
    tempDir = await Directory.systemTemp.createTemp('backup_test');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Matcher throwsBackupError(BackupError error) => throwsA(
    isA<BackupException>().having((e) => e.error, 'error', error),
  );

  /// Exports [db]'s current contents to a backup file on disk.
  Future<String> exportToFile({String name = 'backup.db'}) async {
    final bytes = await repo.exportDatabaseBytes();
    final path = '${tempDir.path}/$name';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  test('orderedTables covers every table exactly once', () {
    expect(
      repo.orderedTables.map((t) => t.actualTableName).toSet(),
      db.allTables.map((t) => t.actualTableName).toSet(),
    );
    expect(repo.orderedTables, hasLength(db.allTables.length));
  });

  test('exportDatabaseBytes produces a SQLite snapshot', () async {
    await seedFullDataset(db);
    final bytes = await repo.exportDatabaseBytes();
    expect(String.fromCharCodes(bytes.take(15)), 'SQLite format 3');
  });

  test(
    'exportJsonString emits a versioned document with every table',
    () async {
      await seedFullDataset(db);
      final decoded = jsonDecode(await repo.exportJsonString());

      expect(decoded, isA<Map<String, dynamic>>());
      final map = decoded as Map<String, dynamic>;
      expect(map['format'], 'gut-journey-export');
      expect(map['schemaVersion'], db.schemaVersion);
      expect(map['exportedAt'], '2026-07-14T12:00:00.000Z');

      final data = map['data'] as Map<String, dynamic>;
      expect(
        data.keys.toSet(),
        db.allTables.map((t) => t.actualTableName).toSet(),
      );
      final foods = data['food_items'] as List<dynamic>;
      expect((foods.single as Map<String, dynamic>)['name'], 'Oats');
      final meals = data['meal_entries'] as List<dynamic>;
      final meal = meals.single as Map<String, dynamic>;
      // Dates are serialized as readable ISO-8601 strings, not timestamps.
      expect(meal['occurredAt'], startsWith('2026-07-14T12:00'));
    },
  );

  test('restore replaces the target database with the backup', () async {
    await seedFullDataset(db);
    final path = await exportToFile();

    final target = createTestDatabase();
    addTearDown(target.close);
    final targetRepo = BackupRepository(target, clock.call);
    await target
        .into(target.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-zebra',
            name: 'Zebra biscuit',
            createdAt: clock.now,
            updatedAt: clock.now,
          ),
        );

    await targetRepo.restoreDatabase(path);

    for (final table in repo.orderedTables) {
      expect(
        await countRows(target, table.actualTableName),
        await countRows(db, table.actualTableName),
        reason: '${table.actualTableName} should match the backup',
      );
    }

    final foods = await target.select(target.foodItems).get();
    expect(foods.map((f) => f.name), ['Oats']);

    // The relational graph survived: meal → item → food joins still work.
    final items = await target.select(target.mealEntryItems).get();
    expect(items.single.mealEntryId, 'meal-1');
    expect(items.single.foodItemId, 'food-1');

    // Symptom presets came from the backup without unique-key clashes.
    final types = await target.select(target.symptomTypes).get();
    expect(types, hasLength(symptomPresetKeys.length + 1));
    expect(types.map((t) => t.customName), contains('Brain fog'));

    final meds = await target.select(target.medications).get();
    expect(meds.single.scheduledTimes, ['08:00']);
  });

  test('restore wakes up live stream queries', () async {
    await seedFullDataset(db);
    final path = await exportToFile();

    final target = createTestDatabase();
    addTearDown(target.close);
    final targetRepo = BackupRepository(target, clock.call);

    final sawRestoredFood = expectLater(
      target.select(target.foodItems).watch(),
      emitsThrough(
        predicate<List<FoodItemRow>>(
          (rows) => rows.any((r) => r.name == 'Oats'),
        ),
      ),
    );
    await targetRepo.restoreDatabase(path);
    await sawRestoredFood;
  });

  test('restore does not modify the source backup file', () async {
    await seedFullDataset(db);
    final path = await exportToFile();
    final bytesBefore = await File(path).readAsBytes();

    final target = createTestDatabase();
    addTearDown(target.close);
    await BackupRepository(target, clock.call).restoreDatabase(path);

    expect(await File(path).readAsBytes(), bytesBefore);
  });

  test('rejects files that are not SQLite databases', () async {
    final path = '${tempDir.path}/not-a-db.txt';
    await File(path).writeAsString('just some text, definitely not SQLite');
    await expectLater(
      repo.restoreDatabase(path),
      throwsBackupError(BackupError.notABackup),
    );

    final emptyPath = '${tempDir.path}/empty.db';
    await File(emptyPath).writeAsBytes([]);
    await expectLater(
      repo.restoreDatabase(emptyPath),
      throwsBackupError(BackupError.notABackup),
    );
  });

  test('rejects corrupt files that still carry the SQLite header', () async {
    final path = '${tempDir.path}/corrupt.db';
    await File(path).writeAsBytes([
      ...'SQLite format 3\u0000'.codeUnits,
      ...List.filled(200, 0xAB),
    ]);
    await expectLater(
      repo.restoreDatabase(path),
      throwsBackupError(BackupError.notABackup),
    );
  });

  test('rejects SQLite files missing the Gut Journey tables', () async {
    await seedFullDataset(db);
    final path = await exportToFile();

    // Turn the valid backup into a foreign SQLite file.
    final scratch = AppDatabase(NativeDatabase(File(path)));
    await scratch.customStatement('PRAGMA foreign_keys = OFF');
    await scratch.customStatement('DROP TABLE food_items');
    await scratch.close();

    await expectLater(
      repo.restoreDatabase(path),
      throwsBackupError(BackupError.notABackup),
    );
  });

  test('rejects backups written by a newer app version', () async {
    await seedFullDataset(db);
    final path = await exportToFile();

    final scratch = AppDatabase(NativeDatabase(File(path)));
    await scratch.customStatement('PRAGMA user_version = 99');
    await scratch.close();

    await expectLater(
      repo.restoreDatabase(path),
      throwsBackupError(BackupError.newerSchema),
    );
  });

  test('a failed restore leaves the target database untouched', () async {
    final target = createTestDatabase();
    addTearDown(target.close);
    await target
        .into(target.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: 'food-keep',
            name: 'Keep me',
            createdAt: clock.now,
            updatedAt: clock.now,
          ),
        );

    final path = '${tempDir.path}/broken.txt';
    await File(path).writeAsString('nope');
    await expectLater(
      BackupRepository(target, clock.call).restoreDatabase(path),
      throwsBackupError(BackupError.notABackup),
    );

    final foods = await target.select(target.foodItems).get();
    expect(foods.map((f) => f.name), ['Keep me']);
  });
}
