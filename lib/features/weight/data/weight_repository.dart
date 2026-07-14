import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/weight/domain/weight_entry.dart';

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) =>
      WeightRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class WeightRepository {
  WeightRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<WeightEntry>> watchByDay(LocalDay day) {
    final statement = _db.select(_db.weightEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  /// Most recent measurement — used to pre-fill the weight sheet.
  Future<WeightEntry?> getLatest() async {
    final row =
        await (_db.select(_db.weightEntries)
              ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.toDomain();
  }

  Future<String> add({
    required double weightKg,
    required DateTime occurredAt,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.weightEntries)
        .insert(
          WeightEntriesCompanion.insert(
            id: id,
            weightKg: weightKg,
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(WeightEntry entry) async {
    await (_db.update(
      _db.weightEntries,
    )..where((t) => t.id.equals(entry.id))).write(
      WeightEntriesCompanion(
        weightKg: Value(entry.weightKg),
        occurredAt: Value(entry.occurredAt.toUtc()),
        localDay: Value(LocalDay.fromDateTime(entry.occurredAt).value),
        notes: Value(entry.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.weightEntries)..where((t) => t.id.equals(id))).go();
  }
}

extension WeightEntryRowToDomain on WeightEntryRow {
  WeightEntry toDomain() => WeightEntry(
    id: id,
    weightKg: weightKg,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
