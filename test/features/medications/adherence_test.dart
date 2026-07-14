import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';

void main() {
  final med = Medication(
    id: 'med-1',
    name: 'Mebeverine',
    scheduleType: ScheduleType.daily,
    scheduledTimes: const ['08:00', '20:00'],
    startDay: LocalDay('2026-07-10'),
  );

  MedicationIntake taken(String day, {String medicationId = 'med-1'}) =>
      MedicationIntake(
        id: 'intake-$day-${DateTime.parse(day).microsecondsSinceEpoch}',
        medicationId: medicationId,
        status: IntakeStatus.taken,
        occurredAt: DateTime.parse('${day}T08:00:00Z'),
        day: LocalDay(day),
      );

  group('expectedSlotsOn', () {
    test('is empty before start, after end, when inactive or as-needed', () {
      expect(med.expectedSlotsOn(LocalDay('2026-07-09')), isEmpty);
      expect(med.expectedSlotsOn(LocalDay('2026-07-10')), hasLength(2));

      final ended = med.copyWith(endDay: LocalDay('2026-07-12'));
      expect(ended.expectedSlotsOn(LocalDay('2026-07-13')), isEmpty);

      expect(
        med.copyWith(isActive: false).expectedSlotsOn(LocalDay('2026-07-14')),
        isEmpty,
      );
      expect(
        med
            .copyWith(scheduleType: ScheduleType.asNeeded)
            .expectedSlotsOn(LocalDay('2026-07-14')),
        isEmpty,
      );
    });
  });

  group('computeAdherence', () {
    test('counts taken doses against expected slots over the range', () {
      // 3 days × 2 slots = 6 expected; 3 taken.
      final summary = computeAdherence(
        medication: med,
        intakes: [
          taken('2026-07-12'),
          taken('2026-07-12'),
          taken('2026-07-13'),
        ],
        from: LocalDay('2026-07-12'),
        to: LocalDay('2026-07-14'),
      );
      expect(summary.expectedDoses, 6);
      expect(summary.takenDoses, 3);
      expect(summary.ratio, 0.5);
    });

    test('caps extra intakes at the expected count per day', () {
      final summary = computeAdherence(
        medication: med,
        intakes: [
          taken('2026-07-12'),
          taken('2026-07-12'),
          taken('2026-07-12'), // third intake of a 2-slot day
        ],
        from: LocalDay('2026-07-12'),
        to: LocalDay('2026-07-12'),
      );
      expect(summary.takenDoses, 2);
      expect(summary.ratio, 1.0);
    });

    test('ignores other medications and out-of-range days', () {
      final summary = computeAdherence(
        medication: med,
        intakes: [
          taken('2026-07-12', medicationId: 'other-med'),
          taken('2026-07-09'), // before range
        ],
        from: LocalDay('2026-07-12'),
        to: LocalDay('2026-07-12'),
      );
      expect(summary.takenDoses, 0);
    });

    test('only expects doses inside the medication window', () {
      // Range starts before the medication does.
      final summary = computeAdherence(
        medication: med,
        intakes: const [],
        from: LocalDay('2026-07-08'),
        to: LocalDay('2026-07-11'),
      );
      expect(summary.expectedDoses, 4); // only the 10th and 11th
    });

    test('as-needed medications have no ratio', () {
      final summary = computeAdherence(
        medication: med.copyWith(scheduleType: ScheduleType.asNeeded),
        intakes: [taken('2026-07-12')],
        from: LocalDay('2026-07-12'),
        to: LocalDay('2026-07-12'),
      );
      expect(summary.expectedDoses, 0);
      expect(summary.ratio, isNull);
    });
  });
}
