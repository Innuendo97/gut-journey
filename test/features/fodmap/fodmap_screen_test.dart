import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/pump_app.dart';

void main() {
  testApp('More leads to the empty reintroduction screen', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low FODMAP reintroduction'));
    await tester.pumpAndSettle();

    expect(find.text('No tests yet'), findsOneWidget);
    expect(find.text('Groups to test'), findsOneWidget);
    // All six groups listed, none badged yet.
    expect(find.text('Lactose'), findsOneWidget);
    expect(find.text('Fructans'), findsOneWidget);
  });

  testApp('starting a test creates the active challenge card', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low FODMAP reintroduction'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start a test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lactose').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Current test'), findsOneWidget);
    // Clock is pinned to 2026-07-14 → day 1.
    expect(find.textContaining('Day 1'), findsOneWidget);
    expect(find.text('Start washout'), findsOneWidget);
  });

  testApp('the outcome sheet lists test-window symptoms and completes', (
    tester,
    harness,
  ) async {
    final fodmap = FodmapRepository(harness.db, harness.clock.call);
    final symptoms = SymptomRepository(harness.db, harness.clock.call);
    final id = await fodmap.startChallenge(
      group: FodmapGroup.sorbitol,
      startDay: LocalDay('2026-07-12'),
    );
    await symptoms.addEntry(
      symptomTypeId: symptomPresetId('bloating'),
      intensity: 6,
      occurredAt: DateTime(2026, 7, 13, 15),
    );
    await symptoms.addEntry(
      symptomTypeId: symptomPresetId('bloating'),
      intensity: 4,
      occurredAt: DateTime(2026, 7, 14, 9),
    );
    // Outside the window: logged before the test started.
    await symptoms.addEntry(
      symptomTypeId: symptomPresetId('nausea'),
      intensity: 5,
      occurredAt: DateTime(2026, 7, 10, 9),
    );

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low FODMAP reintroduction'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record outcome'));
    await tester.pumpAndSettle();

    expect(find.text('Symptoms logged during the test'), findsOneWidget);
    expect(find.text('Bloating'), findsOneWidget);
    expect(find.text('2× · up to intensity 6'), findsOneWidget);
    expect(find.text('Nausea'), findsNothing);

    await tester.tap(find.text('Some symptoms observed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // One-shot select: a drift stream read would park on the stream-query
    // timers that never fire under fake async.
    final done =
        (await harness.db.select(harness.db.fodmapChallenges).get()).single;
    expect(done.id, id);
    expect(done.status, ChallengeStatus.completed);
    expect(done.outcome, ObservedOutcome.someSymptoms);
    // Back on the screen: the outcome shows in history and on the chip row.
    expect(find.text('Past tests'), findsOneWidget);
    expect(find.text('Some symptoms observed'), findsOneWidget);
  });

  testApp('tagging a food stores the namespaced fodmap attribute', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final milk = await foods.create('Milk');

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low FODMAP reintroduction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tag foods with their FODMAP group'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('No group'), findsOneWidget);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lactose'));
    await tester.pumpAndSettle();

    expect(find.text('Lactose'), findsOneWidget); // now the subtitle
    expect(await foods.getAttributes(milk.id, source: 'fodmap'), {
      'group': 'lactose',
    });
  });
}
