import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/water/domain/water_intake.dart';

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) =>
      WaterRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class WaterRepository {
  WaterRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<WaterIntake>> watchByDay(LocalDay day) {
    final statement = _db.select(_db.waterEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Future<String> add({
    required int amountMl,
    required DateTime occurredAt,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.waterEntries)
        .insert(
          WaterEntriesCompanion.insert(
            id: id,
            amountMl: amountMl,
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.waterEntries)..where((t) => t.id.equals(id))).go();
  }
}

extension WaterEntryRowToDomain on WaterEntryRow {
  WaterIntake toDomain() => WaterIntake(
    id: id,
    amountMl: amountMl,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
