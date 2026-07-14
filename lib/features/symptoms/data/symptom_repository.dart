import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';

final symptomRepositoryProvider = Provider<SymptomRepository>(
  (ref) =>
      SymptomRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class SymptomRepository {
  SymptomRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Symptom vocabulary, presets first. Archived types are hidden from
  /// pickers by default but stay resolvable for old entries.
  Stream<List<SymptomType>> watchTypes({bool includeArchived = false}) {
    final statement = _db.select(_db.symptomTypes);
    if (!includeArchived) {
      statement.where((t) => t.isArchived.equals(false));
    }
    statement.orderBy([
      (t) => OrderingTerm.desc(t.presetKey.isNotNull()),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Future<SymptomType> addCustomType(String name) async {
    final type = SymptomType(id: newEntryId(), customName: name.trim());
    await _db
        .into(_db.symptomTypes)
        .insert(
          SymptomTypesCompanion.insert(
            id: type.id,
            customName: Value(type.customName),
            createdAt: _clock().toUtc(),
          ),
        );
    return type;
  }

  Future<void> setTypeArchived(String id, {required bool isArchived}) async {
    await (_db.update(_db.symptomTypes)..where((t) => t.id.equals(id))).write(
      SymptomTypesCompanion(isArchived: Value(isArchived)),
    );
  }

  Stream<List<SymptomEntry>> watchByDay(LocalDay day) {
    final statement = _db.select(_db.symptomEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Future<String> addEntry({
    required String symptomTypeId,
    required int intensity,
    required DateTime occurredAt,
    int? durationMinutes,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.symptomEntries)
        .insert(
          SymptomEntriesCompanion.insert(
            id: id,
            symptomTypeId: symptomTypeId,
            intensity: intensity,
            durationMinutes: Value(durationMinutes),
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateEntry(SymptomEntry entry) async {
    await (_db.update(
      _db.symptomEntries,
    )..where((t) => t.id.equals(entry.id))).write(
      SymptomEntriesCompanion(
        symptomTypeId: Value(entry.symptomTypeId),
        intensity: Value(entry.intensity),
        durationMinutes: Value(entry.durationMinutes),
        occurredAt: Value(entry.occurredAt.toUtc()),
        localDay: Value(LocalDay.fromDateTime(entry.occurredAt).value),
        notes: Value(entry.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> deleteEntry(String id) async {
    await (_db.delete(_db.symptomEntries)..where((t) => t.id.equals(id))).go();
  }
}

extension SymptomTypeRowToDomain on SymptomTypeRow {
  SymptomType toDomain() => SymptomType(
    id: id,
    presetKey: presetKey,
    customName: customName,
    isArchived: isArchived,
  );
}

extension SymptomEntryRowToDomain on SymptomEntryRow {
  SymptomEntry toDomain() => SymptomEntry(
    id: id,
    symptomTypeId: symptomTypeId,
    intensity: intensity,
    durationMinutes: durationMinutes,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
