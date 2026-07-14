import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  final day = LocalDay('2026-07-14');
  final afternoon = DateTime(2026, 7, 14, 16);

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
  });

  tearDown(() async {
    await db.close();
  });

  group('BowelRepository', () {
    test('round-trips all Bristol fields and flags', () async {
      final repo = BowelRepository(db, clock.call);
      await repo.add(
        bristolType: 6,
        occurredAt: afternoon,
        urgency: true,
        pain: 4,
        mucus: true,
      );

      final entry = (await repo.watchByDay(day).first).single;
      expect(entry.bristolType, 6);
      expect(entry.urgency, isTrue);
      expect(entry.pain, 4);
      expect(entry.blood, isFalse);
      expect(entry.mucus, isTrue);

      await repo.update(entry.copyWith(bristolType: 4, pain: null));
      final updated = (await repo.watchByDay(day).first).single;
      expect(updated.bristolType, 4);
      expect(updated.pain, isNull);

      await repo.delete(entry.id);
      expect(await repo.watchByDay(day).first, isEmpty);
    });
  });

  group('WeightRepository', () {
    test('stores kilograms and exposes the latest measurement', () async {
      final repo = WeightRepository(db, clock.call);
      await repo.add(weightKg: 71.5, occurredAt: DateTime(2026, 7, 13, 8));
      await repo.add(weightKg: 70.8, occurredAt: DateTime(2026, 7, 14, 8));

      expect((await repo.getLatest())?.weightKg, 70.8);
      expect((await repo.watchByDay(day).first).single.weightKg, 70.8);
    });
  });

  group('WaterRepository', () {
    test('accumulates multiple entries per day', () async {
      final repo = WaterRepository(db, clock.call);
      await repo.add(amountMl: 250, occurredAt: DateTime(2026, 7, 14, 9));
      await repo.add(amountMl: 500, occurredAt: DateTime(2026, 7, 14, 12));

      final entries = await repo.watchByDay(day).first;
      expect(entries.map((e) => e.amountMl), [250, 500]);

      await repo.delete(entries.first.id);
      expect(await repo.watchByDay(day).first, hasLength(1));
    });
  });

  group('SleepRepository', () {
    test('upserts a single night per wake-up day', () async {
      final repo = SleepRepository(db, clock.call);
      await repo.upsertForDay(day: day, durationMinutes: 420, quality: 3);
      await repo.upsertForDay(day: day, durationMinutes: 450, quality: 4);

      final night = await repo.watchByDay(day).first;
      expect(night?.durationMinutes, 450);
      expect(night?.quality, 4);
      expect(await db.select(db.sleepEntries).get(), hasLength(1));

      await repo.deleteForDay(day);
      expect(await repo.watchByDay(day).first, isNull);
    });
  });

  group('ActivityRepository', () {
    test('logs sessions and suggests distinct recent names', () async {
      final repo = ActivityRepository(db, clock.call);
      await repo.add(
        name: 'Walking',
        durationMinutes: 30,
        effort: Effort.light,
        occurredAt: DateTime(2026, 7, 12, 18),
      );
      await repo.add(
        name: 'Swimming',
        durationMinutes: 45,
        effort: Effort.moderate,
        occurredAt: DateTime(2026, 7, 13, 18),
      );
      await repo.add(
        name: 'Walking',
        durationMinutes: 20,
        effort: Effort.light,
        occurredAt: afternoon,
      );

      expect(await repo.recentNames(), ['Walking', 'Swimming']);

      final today = (await repo.watchByDay(day).first).single;
      expect(today.name, 'Walking');
      expect(today.effort, Effort.light);
    });
  });
}
