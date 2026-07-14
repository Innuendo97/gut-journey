import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/bowel/domain/bowel_movement.dart';

final bowelRepositoryProvider = Provider<BowelRepository>(
  (ref) =>
      BowelRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

class BowelRepository {
  BowelRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<BowelMovement>> watchByDay(LocalDay day) {
    final statement = _db.select(_db.bowelEntries)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Future<String> add({
    required int bristolType,
    required DateTime occurredAt,
    bool urgency = false,
    int? pain,
    bool blood = false,
    bool mucus = false,
    bool incompleteEvacuation = false,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.bowelEntries)
        .insert(
          BowelEntriesCompanion.insert(
            id: id,
            bristolType: bristolType,
            urgency: Value(urgency),
            pain: Value(pain),
            blood: Value(blood),
            mucus: Value(mucus),
            incompleteEvacuation: Value(incompleteEvacuation),
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(BowelMovement movement) async {
    await (_db.update(
      _db.bowelEntries,
    )..where((t) => t.id.equals(movement.id))).write(
      BowelEntriesCompanion(
        bristolType: Value(movement.bristolType),
        urgency: Value(movement.urgency),
        pain: Value(movement.pain),
        blood: Value(movement.blood),
        mucus: Value(movement.mucus),
        incompleteEvacuation: Value(movement.incompleteEvacuation),
        occurredAt: Value(movement.occurredAt.toUtc()),
        localDay: Value(LocalDay.fromDateTime(movement.occurredAt).value),
        notes: Value(movement.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.bowelEntries)..where((t) => t.id.equals(id))).go();
  }
}

extension BowelEntryRowToDomain on BowelEntryRow {
  BowelMovement toDomain() => BowelMovement(
    id: id,
    bristolType: bristolType,
    urgency: urgency,
    pain: pain,
    blood: blood,
    mucus: mucus,
    incompleteEvacuation: incompleteEvacuation,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
