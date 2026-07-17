import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/converters/string_list_converter.dart';
import 'package:gut_journey/core/db/schema_versions.dart';
import 'package:gut_journey/core/db/tables/body_tables.dart';
import 'package:gut_journey/core/db/tables/bowel_tables.dart';
import 'package:gut_journey/core/db/tables/fodmap_tables.dart';
import 'package:gut_journey/core/db/tables/food_tables.dart';
import 'package:gut_journey/core/db/tables/meal_tables.dart';
import 'package:gut_journey/core/db/tables/medication_tables.dart';
import 'package:gut_journey/core/db/tables/symptom_tables.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodItems,
    FoodAttributes,
    MealEntries,
    MealEntryItems,
    SymptomTypes,
    SymptomEntries,
    BowelEntries,
    WeightEntries,
    WaterEntries,
    SleepEntries,
    ActivityEntries,
    Medications,
    MedicationIntakes,
    FodmapChallenges,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedSymptomPresets();
    },
    // Every schema bump ships its step here (generated helpers in
    // schema_versions.dart) plus a test in test/core/db/migration_test.dart.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.fodmapChallenges);
        await m.createIndex(schema.idxFodmapChallengesStartDay);
      },
      from2To3: (m, schema) async {
        await m.addColumn(
          schema.mealEntryItems,
          schema.mealEntryItems.quantity,
        );
      },
      from3To4: (m, schema) async {
        await m.addColumn(
          schema.mealEntryItems,
          schema.mealEntryItems.amountG,
        );
      },
    ),
    beforeOpen: (details) async {
      // Required for the CASCADE/RESTRICT actions declared on references.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedSymptomPresets() async {
    final now = DateTime.now().toUtc();
    await batch((b) {
      b.insertAll(symptomTypes, [
        for (final key in symptomPresetKeys)
          SymptomTypesCompanion.insert(
            id: symptomPresetId(key),
            presetKey: Value(key),
            createdAt: now,
          ),
      ]);
    });
  }
}
