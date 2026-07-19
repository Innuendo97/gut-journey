import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

void main() {
  Medication med({
    ScheduleType scheduleType = ScheduleType.daily,
    String startDay = '2026-07-01',
    String? endDay,
    bool isActive = true,
    List<String> times = const ['08:00', '20:00'],
  }) => Medication(
    id: 'm1',
    name: 'Mesalazine',
    scheduleType: scheduleType,
    startDay: LocalDay(startDay),
    endDay: endDay == null ? null : LocalDay(endDay),
    isActive: isActive,
    scheduledTimes: times,
  );

  group('coversDay', () {
    test('is bounded by the start day', () {
      expect(med().coversDay(LocalDay('2026-06-30')), isFalse);
      expect(med().coversDay(LocalDay('2026-07-01')), isTrue);
    });

    test('is open-ended without an end day', () {
      expect(med().coversDay(LocalDay('2030-01-01')), isTrue);
    });

    test('includes the end day itself and nothing after', () {
      final bounded = med(endDay: '2026-07-10');
      expect(bounded.coversDay(LocalDay('2026-07-10')), isTrue);
      expect(bounded.coversDay(LocalDay('2026-07-11')), isFalse);
    });

    test('ignores isActive: past days keep their ended therapy', () {
      final ended = med(endDay: '2026-07-10', isActive: false);
      expect(ended.coversDay(LocalDay('2026-07-05')), isTrue);
    });
  });

  group('expectedSlotsOn', () {
    test('returns the slots inside the window', () {
      expect(
        med().expectedSlotsOn(LocalDay('2026-07-02')),
        ['08:00', '20:00'],
      );
    });

    test('is empty outside the window', () {
      final bounded = med(endDay: '2026-07-10');
      expect(bounded.expectedSlotsOn(LocalDay('2026-06-30')), isEmpty);
      expect(bounded.expectedSlotsOn(LocalDay('2026-07-11')), isEmpty);
    });

    test('is empty for as-needed medications', () {
      expect(
        med(
          scheduleType: ScheduleType.asNeeded,
          times: const [],
        ).expectedSlotsOn(LocalDay('2026-07-02')),
        isEmpty,
      );
    });

    test('still expects doses on covered days when inactive', () {
      final ended = med(endDay: '2026-07-10', isActive: false);
      expect(
        ended.expectedSlotsOn(LocalDay('2026-07-05')),
        ['08:00', '20:00'],
      );
    });
  });
}
