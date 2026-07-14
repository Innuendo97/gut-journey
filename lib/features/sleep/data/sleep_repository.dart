import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/sleep/domain/sleep_entry.dart';

final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) =>
      SleepRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class SleepRepository {
  SleepRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<SleepEntry?> watchByDay(LocalDay day) {
    final statement = _db.select(_db.sleepEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..limit(1);
    return statement.watchSingleOrNull().map((row) => row?.toDomain());
  }

  /// Creates or replaces the night ending on [day] — at most one per day.
  Future<void> upsertForDay({
    required LocalDay day,
    required int durationMinutes,
    DateTime? bedAt,
    DateTime? wokeAt,
    int? quality,
    String? notes,
  }) async {
    final now = _clock().toUtc();
    final existing =
        await (_db.select(_db.sleepEntries)
              ..where((t) => t.localDay.equals(day.value))
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.sleepEntries)
          .insert(
            SleepEntriesCompanion.insert(
              id: newEntryId(),
              localDay: day.value,
              durationMinutes: durationMinutes,
              bedAt: Value(bedAt?.toUtc()),
              wokeAt: Value(wokeAt?.toUtc()),
              quality: Value(quality),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.sleepEntries,
      )..where((t) => t.id.equals(existing.id))).write(
        SleepEntriesCompanion(
          durationMinutes: Value(durationMinutes),
          bedAt: Value(bedAt?.toUtc()),
          wokeAt: Value(wokeAt?.toUtc()),
          quality: Value(quality),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> deleteForDay(LocalDay day) async {
    await (_db.delete(
      _db.sleepEntries,
    )..where((t) => t.localDay.equals(day.value))).go();
  }
}

extension SleepEntryRowToDomain on SleepEntryRow {
  SleepEntry toDomain() => SleepEntry(
    id: id,
    day: LocalDay(localDay),
    durationMinutes: durationMinutes,
    bedAt: bedAt,
    wokeAt: wokeAt,
    quality: quality,
    notes: notes,
  );
}
