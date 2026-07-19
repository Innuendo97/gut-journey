import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

import '../../helpers/pump_app.dart';

/// The Meds button sits past the right edge of the quick-add bar: scroll it
/// into view first.
Future<void> openMedicationSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.descendant(of: find.byType(QuickAddBar), matching: find.text('Meds')),
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
  testApp('long-pressing a slot marks the dose as skipped', (
    tester,
    harness,
  ) async {
    final repo = MedicationRepository(harness.db, harness.clock.call);
    await repo.createMedication(
      name: 'Mesalazine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00'],
      startDay: LocalDay('2026-07-01'),
    );

    await openMedicationSheet(tester);
    await tester.longPress(find.widgetWithText(FilterChip, '08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skipped'));
    await tester.pumpAndSettle();

    var intakes = await harness.db.select(harness.db.medicationIntakes).get();
    expect(intakes.single.status, IntakeStatus.skipped);
    expect(intakes.single.scheduledTime, '08:00');

    // The menu can flip a skipped dose to taken: one intake, not two.
    await tester.longPress(find.widgetWithText(FilterChip, '08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taken'));
    await tester.pumpAndSettle();

    intakes = await harness.db.select(harness.db.medicationIntakes).get();
    expect(intakes.single.status, IntakeStatus.taken);
    expect(intakes.single.scheduledTime, '08:00');
  });

  testApp('skipped doses stay out of the meds progress and show muted in '
      'the timeline', (tester, harness) async {
    final repo = MedicationRepository(harness.db, harness.clock.call);
    final id = await repo.createMedication(
      name: 'Mesalazine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00', '20:00'],
      startDay: LocalDay('2026-07-01'),
    );
    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.skipped,
      occurredAt: DateTime(2026, 7, 14, 8),
      scheduledTime: '08:00',
    );
    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.taken,
      occurredAt: DateTime(2026, 7, 14, 20),
      scheduledTime: '20:00',
    );
    await tester.pumpAndSettle();

    // Only the taken dose counts.
    expect(find.text('1 of 2 doses taken'), findsOneWidget);
    // Both appear in the timeline with their own labels.
    expect(find.text('Skipped · 08:00'), findsOneWidget);
    expect(find.text('Taken · 20:00'), findsOneWidget);
  });

  testApp('deleting and undoing a skipped dose keeps its status', (
    tester,
    harness,
  ) async {
    final repo = MedicationRepository(harness.db, harness.clock.call);
    final id = await repo.createMedication(
      name: 'Mesalazine',
      scheduleType: ScheduleType.daily,
      scheduledTimes: const ['08:00'],
      startDay: LocalDay('2026-07-01'),
    );
    await repo.logIntake(
      medicationId: id,
      status: IntakeStatus.skipped,
      occurredAt: DateTime(2026, 7, 14, 8),
      scheduledTime: '08:00',
      notes: 'felt fine',
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Skipped · 08:00'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      await harness.db.select(harness.db.medicationIntakes).get(),
      isEmpty,
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final restored =
        (await harness.db.select(harness.db.medicationIntakes).get()).single;
    expect(restored.status, IntakeStatus.skipped);
    expect(restored.scheduledTime, '08:00');
    expect(restored.notes, 'felt fine');
  });
}
