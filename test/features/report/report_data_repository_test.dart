import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/report/data/report_data_repository.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/stats/data/stats_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SymptomRepository symptoms;
  late BowelRepository bowel;
  late WeightRepository weight;
  late WaterRepository water;
  late SleepRepository sleep;
  late ActivityRepository activity;
  late MedicationRepository medications;
  late MealRepository meals;
  late ReportDataRepository report;

  final range = DateRange(LocalDay('2026-07-08'), LocalDay('2026-07-14'));

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    symptoms = SymptomRepository(db, clock.call);
    bowel = BowelRepository(db, clock.call);
    weight = WeightRepository(db, clock.call);
    water = WaterRepository(db, clock.call);
    sleep = SleepRepository(db, clock.call);
    activity = ActivityRepository(db, clock.call);
    medications = MedicationRepository(db, clock.call);
    final foods = FoodRepository(db, clock.call);
    meals = MealRepository(db, foods, clock.call);
    report = ReportDataRepository(
      stats: StatsRepository(db, medications),
      diary: DiaryRepository(
        db: db,
        meals: meals,
        symptoms: symptoms,
        bowel: bowel,
        weight: weight,
        medications: medications,
        water: water,
        sleep: sleep,
        activity: activity,
      ),
      symptoms: symptoms,
      medications: medications,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('collects summary aggregates limited to the range', () async {
    final bloating = symptomPresetId('bloating');
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 6,
      occurredAt: DateTime(2026, 7, 10, 9),
    );
    // Outside the range — must not appear anywhere.
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 10,
      occurredAt: DateTime(2026, 7, 1, 9),
    );
    await bowel.add(bristolType: 4, occurredAt: DateTime(2026, 7, 11, 9));
    await weight.add(weightKg: 70, occurredAt: DateTime(2026, 7, 10, 8));
    await water.add(amountMl: 750, occurredAt: DateTime(2026, 7, 10, 9));

    final data = await report.collect(
      range: range,
      includeDailyLog: false,
      waterGoalMl: 2000,
    );

    expect(data.range, range);
    expect(data.symptomFrequency, {bloating: 1});
    expect(data.symptomIntensity[bloating], hasLength(1));
    expect(data.symptomTypesById[bloating], isNotNull);
    expect(data.bristolDistribution, {4: 1});
    expect(data.weightDaily.single.value, 70);
    expect(data.waterDaily.single.value, 750);
    expect(data.waterGoalMl, 2000);
    expect(data.days, isNull);
  });

  test('daily log keeps only non-empty days, chronologically', () async {
    await water.add(amountMl: 250, occurredAt: DateTime(2026, 7, 12, 9));
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, 9, 13),
      items: const [MealItemInput.newFood(name: 'Riso')],
    );

    final data = await report.collect(
      range: range,
      includeDailyLog: true,
      waterGoalMl: 2000,
    );

    final days = data.days!;
    expect(days, hasLength(2));
    expect(days[0].day, LocalDay('2026-07-09'));
    expect(days[0].meals.single.items.single.food.name, 'Riso');
    expect(days[1].day, LocalDay('2026-07-12'));
    expect(days[1].totalWaterMl, 250);
  });

  test('medication names resolve for inactive medications too', () async {
    final id = await medications.createMedication(
      name: 'Mebeverine',
      scheduleType: ScheduleType.asNeeded,
      startDay: LocalDay('2026-07-01'),
    );
    await medications.logIntake(
      medicationId: id,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 10, 8),
    );
    await medications.setActive(id, isActive: false);

    final data = await report.collect(
      range: range,
      includeDailyLog: true,
      waterGoalMl: 2000,
    );

    expect(data.medicationsById[id]?.name, 'Mebeverine');
    expect(data.days!.single.medicationIntakes.single.medicationId, id);
  });
}
