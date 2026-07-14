import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late MedicationRepository repo;

  final day = LocalDay('2026-07-14');

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    repo = MedicationRepository(db, clock.call);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates a scheduled medication and round-trips its times', () async {
    await repo.createMedication(
      name: 'Mebeverine',
      dosage: '135 mg',
      scheduleType: ScheduleType.daily,
      scheduledTimes: ['08:00', '20:00'],
      startDay: LocalDay('2026-07-01'),
    );

    final med = (await repo.watchAll().first).single;
    expect(med.scheduledTimes, ['08:00', '20:00']);
    expect(med.scheduleType, ScheduleType.daily);
    expect(med.startDay, LocalDay('2026-07-01'));
    expect(med.isActive, isTrue);
  });

  test('watchAll can filter to active medications', () async {
    final id = await repo.createMedication(
      name: 'Old med',
      scheduleType: ScheduleType.asNeeded,
      startDay: LocalDay('2026-01-01'),
    );
    await repo.createMedication(
      name: 'Current med',
      scheduleType: ScheduleType.asNeeded,
      startDay: LocalDay('2026-07-01'),
    );
    await repo.setActive(id, isActive: false);

    final active = await repo.watchAll(activeOnly: true).first;
    expect(active.single.name, 'Current med');
    expect(await repo.watchAll().first, hasLength(2));
  });

  test('logs intakes by day and range', () async {
    final id = await repo.createMedication(
      name: 'Mebeverine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: ['08:00'],
      startDay: LocalDay('2026-07-01'),
    );

    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 14, 8, 5),
      scheduledTime: '08:00',
    );
    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.skipped,
      occurredAt: DateTime(2026, 7, 13, 8),
      scheduledTime: '08:00',
    );

    final today = await repo.watchIntakesByDay(day).first;
    expect(today.single.status, IntakeStatus.taken);
    expect(today.single.scheduledTime, '08:00');

    final range = await repo.intakesBetween(LocalDay('2026-07-13'), day);
    expect(range, hasLength(2));
  });

  test('deleting a medication cascades to its intakes', () async {
    final id = await repo.createMedication(
      name: 'Mebeverine',
      scheduleType: ScheduleType.asNeeded,
      startDay: LocalDay('2026-07-01'),
    );
    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 14, 8),
    );

    await repo.deleteMedication(id);

    expect(await repo.watchAll().first, isEmpty);
    expect(await db.select(db.medicationIntakes).get(), isEmpty);
  });
}
