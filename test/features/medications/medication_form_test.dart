import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/presentation/medication_form_screen.dart';

import '../../helpers/pump_app.dart';

Future<void> openMedicationsScreen(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Medications'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  // Release focus first: a software-keyboard inset can leave the button
  // outside the tappable area right after enterText.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  // The form ListView builds lazily and other tab branches keep their own
  // scrollables alive, so scroll the form's list explicitly.
  await tester.scrollUntilVisible(
    find.text('Save'),
    200,
    scrollable: find
        .descendant(
          of: find.byType(MedicationFormScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

// Reads rows directly: drift stream getters (`.first`) deadlock under
// testApp's fake async.
Future<List<Medication>> savedMedications(AppDatabase db) async {
  final rows = await db.select(db.medications).get();
  return [for (final row in rows) row.toDomain()];
}

void main() {
  testApp('new medication defaults to starting today with no end date', (
    tester,
    harness,
  ) async {
    await openMedicationsScreen(tester);
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();

    // FixedClock pins today to 2026-07-14.
    expect(find.text('Jul 14, 2026'), findsOneWidget);
    expect(find.text('No end date'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Mesalazine');
    await tapSave(tester);

    final meds = await savedMedications(harness.db);
    expect(meds.single.startDay, LocalDay('2026-07-14'));
    expect(meds.single.endDay, isNull);
  });

  testApp('start and end dates can be edited and the end date cleared', (
    tester,
    harness,
  ) async {
    final repo = MedicationRepository(harness.db, harness.clock.call);
    await repo.createMedication(
      name: 'Rifaximin',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00'],
      startDay: LocalDay('2026-07-01'),
      endDay: LocalDay('2026-07-10'),
    );

    await openMedicationsScreen(tester);
    await tester.tap(find.text('Rifaximin'));
    await tester.pumpAndSettle();

    expect(find.text('Jul 1, 2026'), findsOneWidget);
    expect(find.text('Jul 10, 2026'), findsOneWidget);

    // Move the start date to July 2 via the date picker.
    await tester.tap(find.text('Start date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Jul 2, 2026'), findsOneWidget);

    // Clear the end date.
    await tester.tap(find.byTooltip('Clear end date'));
    await tester.pumpAndSettle();
    expect(find.text('No end date'), findsOneWidget);

    await tapSave(tester);

    final meds = await savedMedications(harness.db);
    expect(meds.single.startDay, LocalDay('2026-07-02'));
    expect(meds.single.endDay, isNull);
  });

  testApp('an end date before the start date blocks saving', (
    tester,
    harness,
  ) async {
    final repo = MedicationRepository(harness.db, harness.clock.call);
    await repo.createMedication(
      name: 'Rifaximin',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00'],
      startDay: LocalDay('2026-07-05'),
      endDay: LocalDay('2026-07-08'),
    );

    await openMedicationsScreen(tester);
    await tester.tap(find.text('Rifaximin'));
    await tester.pumpAndSettle();

    // Move the start date past the end date: the picker allows it, save
    // must not.
    await tester.tap(find.text('Start date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(
      find.text("End date can't be before the start date"),
      findsOneWidget,
    );
    final meds = await savedMedications(harness.db);
    expect(meds.single.startDay, LocalDay('2026-07-05'));
  });
}
