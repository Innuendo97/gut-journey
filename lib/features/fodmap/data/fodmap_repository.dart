import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';

final fodmapRepositoryProvider = Provider<FodmapRepository>(
  (ref) =>
      FodmapRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// The reintroduction path's write/read surface. One challenge runs at a
/// time; what happened during it lives in the regular diary — this table
/// only records the plan and the observed outcome.
class FodmapRepository {
  FodmapRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const _activeStatuses = [
    ChallengeStatus.testing,
    ChallengeStatus.washout,
  ];

  Stream<List<FodmapChallenge>> watchChallenges() {
    final statement = _db.select(_db.fodmapChallenges)
      ..orderBy([(t) => OrderingTerm.desc(t.startDay)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Stream<FodmapChallenge?> watchActiveChallenge() {
    final statement = _db.select(_db.fodmapChallenges)
      ..where((t) => t.status.isInValues(_activeStatuses))
      ..limit(1);
    return statement.watch().map(
      (rows) => rows.isEmpty ? null : rows.single.toDomain(),
    );
  }

  /// Starts testing [group]. Throws [StateError] while another challenge is
  /// running — the path is one group at a time by design.
  Future<String> startChallenge({
    required FodmapGroup group,
    required LocalDay startDay,
  }) async {
    return _db.transaction(() async {
      final active =
          await (_db.select(_db.fodmapChallenges)
                ..where((t) => t.status.isInValues(_activeStatuses))
                ..limit(1))
              .get();
      if (active.isNotEmpty) {
        throw StateError('A challenge is already in progress');
      }
      final id = newEntryId();
      final now = _clock().toUtc();
      await _db
          .into(_db.fodmapChallenges)
          .insert(
            FodmapChallengesCompanion.insert(
              id: id,
              fodmapGroup: group,
              status: ChallengeStatus.testing,
              startDay: startDay.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  Future<void> moveToWashout(String id, {required LocalDay testEndDay}) =>
      _update(
        id,
        FodmapChallengesCompanion(
          status: const Value(ChallengeStatus.washout),
          testEndDay: Value(testEndDay.value),
        ),
      );

  Future<void> completeChallenge(
    String id, {
    required ObservedOutcome outcome,
    required LocalDay completedDay,
    String? note,
  }) => _update(
    id,
    FodmapChallengesCompanion(
      status: const Value(ChallengeStatus.completed),
      completedDay: Value(completedDay.value),
      outcome: Value(outcome),
      outcomeNote: Value(note),
    ),
  );

  Future<void> abandonChallenge(String id) => _update(
    id,
    const FodmapChallengesCompanion(
      status: Value(ChallengeStatus.abandoned),
    ),
  );

  Future<void> _update(String id, FodmapChallengesCompanion changes) async {
    await (_db.update(_db.fodmapChallenges)..where((t) => t.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(_clock().toUtc())));
  }
}

extension FodmapChallengeRowToDomain on FodmapChallengeRow {
  FodmapChallenge toDomain() => FodmapChallenge(
    id: id,
    group: fodmapGroup,
    status: status,
    startDay: LocalDay(startDay),
    testEndDay: testEndDay == null ? null : LocalDay(testEndDay!),
    completedDay: completedDay == null ? null : LocalDay(completedDay!),
    outcome: outcome,
    outcomeNote: outcomeNote,
  );
}
