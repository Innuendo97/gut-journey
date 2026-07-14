// The self-reference inside check() is the documented drift pattern for
// column constraints, not a real recursive getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';

@TableIndex(name: 'idx_weight_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_weight_entries_occurred_at', columns: {#occurredAt})
@DataClassName('WeightEntryRow')
class WeightEntries extends Table with AuditColumns, EntryColumns {
  /// Always stored metric; unit conversion is a presentation concern.
  RealColumn get weightKg => real()();
}

@TableIndex(name: 'idx_water_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_water_entries_occurred_at', columns: {#occurredAt})
@DataClassName('WaterEntryRow')
class WaterEntries extends Table with AuditColumns, EntryColumns {
  IntColumn get amountMl => integer()();
}

/// One entry per day, keyed on the wake-up day.
@TableIndex(name: 'idx_sleep_entries_local_day', columns: {#localDay})
@DataClassName('SleepEntryRow')
class SleepEntries extends Table with AuditColumns {
  TextColumn get localDay => text().withLength(min: 10, max: 10).unique()();
  DateTimeColumn get bedAt => dateTime().nullable()();
  DateTimeColumn get wokeAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer()();
  IntColumn get quality =>
      integer().nullable().check(quality.isBetweenValues(1, 5))();
  TextColumn get notes => text().nullable()();
}

@TableIndex(name: 'idx_activity_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_activity_entries_occurred_at', columns: {#occurredAt})
@DataClassName('ActivityEntryRow')
class ActivityEntries extends Table with AuditColumns, EntryColumns {
  TextColumn get activityName => text()();
  IntColumn get durationMinutes => integer()();
  TextColumn get effort => textEnum<Effort>()();
}
