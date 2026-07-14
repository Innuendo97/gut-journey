import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/stats/data/stats_repository.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late StatsRepository stats;
  late SymptomRepository symptoms;
  late BowelRepository bowel;
  late WeightRepository weight;
  late WaterRepository water;
  late SleepRepository sleep;
  late ActivityRepository activity;
  late MedicationRepository medications;

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
    stats = StatsRepository(db, medications);
  });

  tearDown(() async {
    await db.close();
  });

  test('symptom intensity averages per day and type', () async {
    final bloating = symptomPresetId('bloating');
    final nausea = symptomPresetId('nausea');
    // Two bloating entries on the 10th (avg 6), one on the 12th.
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 4,
      occurredAt: DateTime(2026, 7, 10, 9),
    );
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 8,
      occurredAt: DateTime(2026, 7, 10, 20),
    );
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 3,
      occurredAt: DateTime(2026, 7, 12, 9),
    );
    await symptoms.addEntry(
      symptomTypeId: nausea,
      intensity: 5,
      occurredAt: DateTime(2026, 7, 10, 9),
    );
    // Outside the range — must not appear.
    await symptoms.addEntry(
      symptomTypeId: bloating,
      intensity: 10,
      occurredAt: DateTime(2026, 7, 1, 9),
    );

    final series = await stats.watchSymptomIntensity(range).first;

    expect(series.keys, containsAll([bloating, nausea]));
    expect(series[bloating], [
      DailyValue(LocalDay('2026-07-10'), 6),
      DailyValue(LocalDay('2026-07-12'), 3),
    ]);
    expect(series[nausea], [DailyValue(LocalDay('2026-07-10'), 5)]);
  });

  test('symptom frequency counts, most frequent first', () async {
    final bloating = symptomPresetId('bloating');
    final nausea = symptomPresetId('nausea');
    for (final day in [10, 11, 12]) {
      await symptoms.addEntry(
        symptomTypeId: bloating,
        intensity: 5,
        occurredAt: DateTime(2026, 7, day, 9),
      );
    }
    await symptoms.addEntry(
      symptomTypeId: nausea,
      intensity: 5,
      occurredAt: DateTime(2026, 7, 11, 9),
    );

    final frequency = await stats.watchSymptomFrequency(range).first;
    expect(frequency.entries.first.key, bloating);
    expect(frequency, {bloating: 3, nausea: 1});
  });

  test('bristol distribution counts per type', () async {
    for (final type in [4, 4, 6]) {
      await bowel.add(bristolType: type, occurredAt: DateTime(2026, 7, 11, 9));
    }
    final distribution = await stats.watchBristolDistribution(range).first;
    expect(distribution, {4: 2, 6: 1});
  });

  test('daily aggregates: weight avg, water sum, sleep and activity', () async {
    await weight.add(weightKg: 70, occurredAt: DateTime(2026, 7, 10, 8));
    await weight.add(weightKg: 71, occurredAt: DateTime(2026, 7, 10, 20));
    await water.add(amountMl: 250, occurredAt: DateTime(2026, 7, 10, 9));
    await water.add(amountMl: 500, occurredAt: DateTime(2026, 7, 10, 15));
    await sleep.upsertForDay(day: LocalDay('2026-07-10'), durationMinutes: 420);
    await activity.add(
      name: 'Walking',
      durationMinutes: 30,
      effort: Effort.light,
      occurredAt: DateTime(2026, 7, 10, 18),
    );
    await activity.add(
      name: 'Yoga',
      durationMinutes: 20,
      effort: Effort.light,
      occurredAt: DateTime(2026, 7, 10, 20),
    );

    expect(await stats.watchWeightDaily(range).first, [
      DailyValue(LocalDay('2026-07-10'), 70.5),
    ]);
    expect(await stats.watchWaterDaily(range).first, [
      DailyValue(LocalDay('2026-07-10'), 750),
    ]);
    expect(await stats.watchSleepDaily(range).first, [
      DailyValue(LocalDay('2026-07-10'), 420),
    ]);
    expect(await stats.watchActivityDaily(range).first, [
      DailyValue(LocalDay('2026-07-10'), 50),
    ]);
  });

  test('adherence pairs each active medication with its summary', () async {
    final id = await medications.createMedication(
      name: 'Mebeverine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: ['08:00', '20:00'],
      startDay: LocalDay('2026-07-08'),
    );
    await medications.logIntake(
      medicationId: id,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 10, 8),
      scheduledTime: '08:00',
    );

    final adherence = await stats.watchAdherence(range).first;
    final (medication, summary) = adherence.single;
    expect(medication.id, id);
    expect(summary.expectedDoses, 14); // 7 days × 2 slots
    expect(summary.takenDoses, 1);
  });
}
