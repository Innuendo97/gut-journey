import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/reminders/reminder_plan.dart';

void main() {
  final today = LocalDay('2026-07-14');

  Medication med({
    String id = 'm1',
    bool remindersEnabled = true,
    bool isActive = true,
    ScheduleType scheduleType = ScheduleType.daily,
    String startDay = '2026-07-01',
    String? endDay,
    List<String> times = const ['08:00', '20:00'],
  }) => Medication(
    id: id,
    name: 'Mesalazine',
    scheduleType: scheduleType,
    startDay: LocalDay(startDay),
    endDay: endDay == null ? null : LocalDay(endDay),
    isActive: isActive,
    remindersEnabled: remindersEnabled,
    scheduledTimes: times,
  );

  test('an ongoing therapy becomes one repeating reminder per slot', () {
    final plan = planReminders([med()], today: today);

    expect(plan, hasLength(2));
    expect(plan.map((r) => r.slot), ['08:00', '20:00']);
    expect(plan.every((r) => r.day == null), isTrue);
  });

  test('ineligible medications produce nothing', () {
    final ineligible = [
      med(remindersEnabled: false),
      med(isActive: false),
      med(scheduleType: ScheduleType.asNeeded, times: const []),
      med(times: const []),
      med(endDay: '2026-07-13'), // ended yesterday
    ];

    expect(planReminders(ineligible, today: today), isEmpty);
  });

  test('a bounded therapy gets one occurrence per remaining day and slot', () {
    // Ends July 16: today, the 15th and the 16th remain.
    final plan = planReminders([med(endDay: '2026-07-16')], today: today);

    expect(plan, hasLength(6));
    expect(plan.every((r) => r.day != null), isTrue);
    expect(plan.first.day, today);
    expect(plan.last.day, LocalDay('2026-07-16'));
    // Days already past are never scheduled.
    expect(plan.any((r) => r.day!.isBefore(today)), isFalse);
  });

  test('a future-start therapy schedules from its start day', () {
    final plan = planReminders([
      med(startDay: '2026-07-20', endDay: '2026-07-21'),
    ], today: today);

    expect(plan, hasLength(4));
    expect(plan.first.day, LocalDay('2026-07-20'));
  });

  test('bounded occurrences are capped', () {
    final plan = planReminders([
      med(endDay: '2027-07-14'), // a year out
    ], today: today);

    expect(plan, hasLength(reminderOccurrenceCap));
  });

  test('ids are deterministic and distinct across slots and days', () {
    expect(reminderId('m1', '08:00'), reminderId('m1', '08:00'));
    expect(reminderId('m1', '08:00'), isNot(reminderId('m1', '20:00')));
    expect(reminderId('m1', '08:00'), isNot(reminderId('m2', '08:00')));
    expect(
      reminderId('m1', '08:00', LocalDay('2026-07-14')),
      isNot(reminderId('m1', '08:00', LocalDay('2026-07-15'))),
    );
    // 31-bit positive range, as Android notification ids must be ints.
    expect(reminderId('m1', '08:00'), inInclusiveRange(0, 0x7fffffff));
  });

  test('the same plan is produced for the same input', () {
    final meds = [med(), med(id: 'm2', endDay: '2026-07-16')];
    expect(
      planReminders(meds, today: today),
      planReminders(meds, today: today),
    );
  });
}
