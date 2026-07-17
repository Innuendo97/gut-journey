import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FodmapRepository repo;

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    repo = FodmapRepository(db, clock.call);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts a challenge and exposes it as active', () async {
    final id = await repo.startChallenge(
      group: FodmapGroup.lactose,
      startDay: LocalDay('2026-07-14'),
    );

    final active = await repo.watchActiveChallenge().first;
    expect(active?.id, id);
    expect(active?.group, FodmapGroup.lactose);
    expect(active?.status, ChallengeStatus.testing);
    expect(active?.startDay, LocalDay('2026-07-14'));
  });

  test('refuses a second challenge while one is running', () async {
    await repo.startChallenge(
      group: FodmapGroup.lactose,
      startDay: LocalDay('2026-07-14'),
    );

    expect(
      () => repo.startChallenge(
        group: FodmapGroup.fructans,
        startDay: LocalDay('2026-07-15'),
      ),
      throwsStateError,
    );
  });

  test(
    'walks testing → washout → completed with the observed outcome',
    () async {
      final id = await repo.startChallenge(
        group: FodmapGroup.sorbitol,
        startDay: LocalDay('2026-07-10'),
      );

      await repo.moveToWashout(id, testEndDay: LocalDay('2026-07-12'));
      var challenge = (await repo.watchChallenges().first).single;
      expect(challenge.status, ChallengeStatus.washout);
      expect(challenge.testEndDay, LocalDay('2026-07-12'));
      // Still active during washout: no new group may start yet.
      expect(await repo.watchActiveChallenge().first, isNotNull);

      await repo.completeChallenge(
        id,
        outcome: ObservedOutcome.someSymptoms,
        completedDay: LocalDay('2026-07-14'),
        note: 'Bloating on day two',
      );
      challenge = (await repo.watchChallenges().first).single;
      expect(challenge.status, ChallengeStatus.completed);
      expect(challenge.outcome, ObservedOutcome.someSymptoms);
      expect(challenge.outcomeNote, 'Bloating on day two');
      expect(challenge.completedDay, LocalDay('2026-07-14'));
      expect(await repo.watchActiveChallenge().first, isNull);
    },
  );

  test('an abandoned challenge frees the slot and keeps its record', () async {
    final id = await repo.startChallenge(
      group: FodmapGroup.fructose,
      startDay: LocalDay('2026-07-10'),
    );
    await repo.abandonChallenge(id);

    expect(await repo.watchActiveChallenge().first, isNull);
    final all = await repo.watchChallenges().first;
    expect(all.single.status, ChallengeStatus.abandoned);

    await repo.startChallenge(
      group: FodmapGroup.mannitol,
      startDay: LocalDay('2026-07-14'),
    );
    expect(await repo.watchChallenges().first, hasLength(2));
  });

  test('history lists challenges newest first', () async {
    final first = await repo.startChallenge(
      group: FodmapGroup.lactose,
      startDay: LocalDay('2026-07-01'),
    );
    await repo.completeChallenge(
      first,
      outcome: ObservedOutcome.noSymptoms,
      completedDay: LocalDay('2026-07-06'),
    );
    await repo.startChallenge(
      group: FodmapGroup.gos,
      startDay: LocalDay('2026-07-08'),
    );

    final all = await repo.watchChallenges().first;
    expect(all.map((c) => c.group), [FodmapGroup.gos, FodmapGroup.lactose]);
  });
}
