import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MealRepository meals;
  late SymptomRepository symptoms;
  late BowelRepository bowel;
  late WeightRepository weight;
  late MedicationRepository medications;
  late WaterRepository water;
  late SleepRepository sleep;
  late ActivityRepository activity;
  late DiaryRepository diary;

  final day = LocalDay('2026-07-14');

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    final foods = FoodRepository(db, clock.call);
    meals = MealRepository(db, foods, clock.call);
    symptoms = SymptomRepository(db, clock.call);
    bowel = BowelRepository(db, clock.call);
    weight = WeightRepository(db, clock.call);
    medications = MedicationRepository(db, clock.call);
    water = WaterRepository(db, clock.call);
    sleep = SleepRepository(db, clock.call);
    activity = ActivityRepository(db, clock.call);
    diary = DiaryRepository(
      meals: meals,
      symptoms: symptoms,
      bowel: bowel,
      weight: weight,
      medications: medications,
      water: water,
      sleep: sleep,
      activity: activity,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('an untouched day is empty', () async {
    final diaryDay = await diary.watchDay(day).first;
    expect(diaryDay.isEmpty, isTrue);
    expect(diaryDay.totalWaterMl, 0);
  });

  test('aggregates every tracker logged on the day', () async {
    await meals.createMeal(
      type: MealType.breakfast,
      occurredAt: DateTime(2026, 7, 14, 8),
      items: const [MealItemInput.newFood(name: 'Oats')],
    );
    await symptoms.addEntry(
      symptomTypeId: symptomPresetId('bloating'),
      intensity: 6,
      occurredAt: DateTime(2026, 7, 14, 10),
    );
    await bowel.add(bristolType: 4, occurredAt: DateTime(2026, 7, 14, 9));
    await weight.add(weightKg: 70.5, occurredAt: DateTime(2026, 7, 14, 7));
    final medId = await medications.createMedication(
      name: 'Mebeverine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: ['08:00'],
      startDay: LocalDay('2026-07-01'),
    );
    await medications.logIntake(
      medicationId: medId,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 14, 8, 5),
      scheduledTime: '08:00',
    );
    await water.add(amountMl: 250, occurredAt: DateTime(2026, 7, 14, 9));
    await water.add(amountMl: 500, occurredAt: DateTime(2026, 7, 14, 13));
    await sleep.upsertForDay(day: day, durationMinutes: 440, quality: 4);
    await activity.add(
      name: 'Walking',
      durationMinutes: 30,
      effort: Effort.light,
      occurredAt: DateTime(2026, 7, 14, 18),
    );

    final diaryDay = await diary.watchDay(day).first;
    expect(diaryDay.isEmpty, isFalse);
    expect(diaryDay.meals, hasLength(1));
    expect(diaryDay.symptoms, hasLength(1));
    expect(diaryDay.bowelMovements, hasLength(1));
    expect(diaryDay.weightEntries, hasLength(1));
    expect(diaryDay.medicationIntakes, hasLength(1));
    expect(diaryDay.waterIntakes, hasLength(2));
    expect(diaryDay.totalWaterMl, 750);
    expect(diaryDay.sleep?.durationMinutes, 440);
    expect(diaryDay.activities, hasLength(1));
  });

  test('re-emits when any underlying tracker changes', () async {
    final emissions = <int>[];
    final subscription = diary
        .watchDay(day)
        .listen((d) => emissions.add(d.totalWaterMl));

    await pumpEventQueue();
    await water.add(amountMl: 250, occurredAt: DateTime(2026, 7, 14, 9));
    await pumpEventQueue();

    expect(emissions.first, 0);
    expect(emissions.last, 250);
    await subscription.cancel();
  });

  test('does not leak entries from neighboring days', () async {
    await water.add(amountMl: 999, occurredAt: DateTime(2026, 7, 13, 23));
    await water.add(amountMl: 100, occurredAt: DateTime(2026, 7, 14, 8));

    final diaryDay = await diary.watchDay(day).first;
    expect(diaryDay.totalWaterMl, 100);
  });
}
