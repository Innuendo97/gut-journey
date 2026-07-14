import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/activity/domain/activity_entry.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);

class ActivityRepository {
  ActivityRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<ActivityEntry>> watchByDay(LocalDay day) {
    final statement = _db.select(_db.activityEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  /// Distinct recent activity names, latest first — powers suggestions in
  /// the activity sheet.
  Future<List<String>> recentNames({int limit = 8}) async {
    final rows =
        await (_db.selectOnly(_db.activityEntries, distinct: true)
              ..addColumns([_db.activityEntries.activityName])
              ..orderBy([
                OrderingTerm.desc(_db.activityEntries.occurredAt.max()),
              ])
              ..groupBy([_db.activityEntries.activityName])
              ..limit(limit))
            .get();
    return [
      for (final row in rows) ?row.read(_db.activityEntries.activityName),
    ];
  }

  Future<String> add({
    required String name,
    required int durationMinutes,
    required Effort effort,
    required DateTime occurredAt,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.activityEntries)
        .insert(
          ActivityEntriesCompanion.insert(
            id: id,
            activityName: name.trim(),
            durationMinutes: durationMinutes,
            effort: effort,
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(ActivityEntry entry) async {
    await (_db.update(
      _db.activityEntries,
    )..where((t) => t.id.equals(entry.id))).write(
      ActivityEntriesCompanion(
        activityName: Value(entry.name.trim()),
        durationMinutes: Value(entry.durationMinutes),
        effort: Value(entry.effort),
        occurredAt: Value(entry.occurredAt.toUtc()),
        localDay: Value(LocalDay.fromDateTime(entry.occurredAt).value),
        notes: Value(entry.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(
      _db.activityEntries,
    )..where((t) => t.id.equals(id))).go();
  }
}

extension ActivityEntryRowToDomain on ActivityEntryRow {
  ActivityEntry toDomain() => ActivityEntry(
    id: id,
    name: activityName,
    durationMinutes: durationMinutes,
    effort: effort,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
