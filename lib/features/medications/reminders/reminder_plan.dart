import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:meta/meta.dart';

/// Hard cap on scheduled occurrences per medication: Android limits an app
/// to ~500 pending alarms, and the plan is rebuilt on every sync anyway.
const reminderOccurrenceCap = 64;

/// One notification to schedule: repeats daily at [slot] when [day] is
/// null, otherwise fires once on [day] at [slot].
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.slot,
    this.day,
  });

  final int id;
  final String medicationId;
  final String medicationName;

  /// "HH:mm".
  final String slot;
  final LocalDay? day;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.medicationId == medicationId &&
      other.medicationName == medicationName &&
      other.slot == slot &&
      other.day == day;

  @override
  int get hashCode => Object.hash(id, medicationId, slot, day);

  @override
  String toString() =>
      'PlannedReminder($medicationName $slot ${day ?? 'daily'})';
}

/// The full set of notifications that should exist right now for
/// [medications]. Pure: the scheduler turns it into platform calls.
///
/// Eligible: reminders enabled, part of the current therapy (isActive),
/// daily schedule, window not already over. Open-ended therapies become one
/// repeating notification per slot; bounded (or not-yet-started) ones get
/// individual day×slot occurrences, capped and refreshed on every sync.
List<PlannedReminder> planReminders(
  List<Medication> medications, {
  required LocalDay today,
}) {
  final plan = <PlannedReminder>[];
  for (final med in medications) {
    if (!med.remindersEnabled || !med.isActive) continue;
    if (med.scheduleType != ScheduleType.daily) continue;
    if (med.scheduledTimes.isEmpty) continue;
    final end = med.endDay;
    if (end != null && end.isBefore(today)) continue;

    if (end == null && !today.isBefore(med.startDay)) {
      for (final slot in med.scheduledTimes) {
        plan.add(
          PlannedReminder(
            id: reminderId(med.id, slot),
            medicationId: med.id,
            medicationName: med.name,
            slot: slot,
          ),
        );
      }
      continue;
    }

    var day = today.isBefore(med.startDay) ? med.startDay : today;
    // Future-start open-ended therapies get a horizon window too; the next
    // sync (every app start) extends it.
    final last = end ?? day.addDays(reminderOccurrenceCap);
    var count = 0;
    while (!day.isAfter(last) && count < reminderOccurrenceCap) {
      for (final slot in med.scheduledTimes) {
        if (count >= reminderOccurrenceCap) break;
        plan.add(
          PlannedReminder(
            id: reminderId(med.id, slot, day),
            medicationId: med.id,
            medicationName: med.name,
            slot: slot,
            day: day,
          ),
        );
        count++;
      }
      day = day.next;
    }
  }
  return plan;
}

/// Deterministic 31-bit notification id (FNV-1a over med|slot|day), so a
/// rebuilt plan overwrites instead of duplicating.
int reminderId(String medicationId, String slot, [LocalDay? day]) {
  var hash = 0x811c9dc5;
  for (final unit in '$medicationId|$slot|${day?.value ?? ''}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
