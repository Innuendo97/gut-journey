import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

import '../../helpers/pump_app.dart';

Future<void> usePhonePortraitSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

/// The Meds button sits past the right edge of the quick-add bar on a
/// portrait surface: scroll it into view first.
Future<void> openMedicationSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.descendant(
      of: find.byType(QuickAddBar),
      matching: find.text('Meds'),
    ),
    100,
    scrollable: find.descendant(
      of: find.byType(QuickAddBar),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
  await tapQuickAdd(tester, 'Meds');
}

void main() {
  testApp('an ended, inactive therapy is still loggable on a covered past '
      'day', (tester, harness) async {
    await usePhonePortraitSurface(tester);
    final repo = MedicationRepository(harness.db, harness.clock.call);
    // Therapy that ran July 1-10 and is no longer part of current therapy.
    final id = await repo.createMedication(
      name: 'Rifaximin',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00'],
      startDay: LocalDay('2026-07-01'),
      endDay: LocalDay('2026-07-10'),
    );
    await repo.setActive(id, isActive: false);

    // Today (July 14) is outside the window: the sheet must not offer it.
    await openMedicationSheet(tester);
    expect(find.text('Rifaximin'), findsNothing);
    expect(find.text('No medications yet'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40)); // dismiss the sheet
    await tester.pumpAndSettle();

    // July 8 from History is covered: log the 08:00 dose there. The month
    // calendar is on demand now — open it from the header first.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8').first);
    await tester.pumpAndSettle();
    await openMedicationSheet(tester);
    expect(find.text('Rifaximin'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '08:00'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    // The intake lands on July 8 with the medication's own name showing in
    // the timeline (not the generic fallback).
    expect(find.text('Rifaximin'), findsOneWidget);
    final intakes = await harness.db.select(harness.db.medicationIntakes).get();
    expect(intakes.single.localDay, '2026-07-08');
    expect(intakes.single.scheduledTime, '08:00');
  });
}
