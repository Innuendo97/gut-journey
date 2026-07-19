import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/presentation/medication_form_screen.dart';
import 'package:gut_journey/features/medications/reminders/notification_scheduler.dart';
import 'package:gut_journey/features/medications/reminders/reminder_plan.dart';

import '../../helpers/pump_app.dart';

/// Records every sync and answers permission requests with a canned value.
class RecordingScheduler implements NotificationScheduler {
  RecordingScheduler({this.grantPermission = true});

  final bool grantPermission;
  final List<List<PlannedReminder>> syncedPlans = [];
  int permissionRequests = 0;
  ReminderStrings? lastStrings;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> sync(List<PlannedReminder> plan, ReminderStrings strings) async {
    syncedPlans.add(plan);
    lastStrings = strings;
  }
}

Future<void> openMedicationsScreen(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Medications'));
  await tester.pumpAndSettle();
}

Future<void> scrollFormTo(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find
        .descendant(
          of: find.byType(MedicationFormScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

void main() {
  final schedulerOnRepoChanges = RecordingScheduler();
  testApp(
    'medication changes drive the scheduler through the planner',
    (tester, harness) async {
      final repo = MedicationRepository(harness.db, harness.clock.call);
      final id = await repo.createMedication(
        name: 'Mesalazine',
        scheduleType: ScheduleType.daily,
        scheduledTimes: const ['08:00', '20:00'],
        startDay: LocalDay('2026-07-01'),
        remindersEnabled: true,
      );
      await tester.pumpAndSettle();

      expect(schedulerOnRepoChanges.syncedPlans, isNotEmpty);
      var plan = schedulerOnRepoChanges.syncedPlans.last;
      expect(plan, hasLength(2));
      expect(plan.map((r) => r.slot), ['08:00', '20:00']);
      expect(schedulerOnRepoChanges.lastStrings?.channelName, isNotNull);

      // Turning reminders off empties the plan on the next emission.
      await repo.setRemindersEnabled(id, enabled: false);
      await tester.pumpAndSettle();
      plan = schedulerOnRepoChanges.syncedPlans.last;
      expect(plan, isEmpty);
    },
    overrides: [
      notificationSchedulerProvider.overrideWithValue(schedulerOnRepoChanges),
    ],
  );

  final schedulerGranting = RecordingScheduler();
  testApp(
    'the form toggle asks for permission and persists the opt-in',
    (tester, harness) async {
      await openMedicationsScreen(tester);
      await tester.tap(find.text('Add medication'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Mesalazine');

      await scrollFormTo(tester, 'Daily reminders');
      await tester.tap(find.text('Daily reminders'));
      await tester.pumpAndSettle();
      expect(schedulerGranting.permissionRequests, 1);

      await scrollFormTo(tester, 'Save');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final rows = await harness.db.select(harness.db.medications).get();
      expect(rows.single.remindersEnabled, isTrue);
    },
    overrides: [
      notificationSchedulerProvider.overrideWithValue(schedulerGranting),
    ],
  );

  final schedulerDenying = RecordingScheduler(grantPermission: false);
  testApp(
    'a denied permission snaps the toggle back and explains why',
    (tester, harness) async {
      await openMedicationsScreen(tester);
      await tester.tap(find.text('Add medication'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Mesalazine');

      await scrollFormTo(tester, 'Daily reminders');
      await tester.tap(find.text('Daily reminders'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(toggle.value, isFalse);
      expect(
        find.text('Notifications are disabled — reminders stay off'),
        findsOneWidget,
      );
      // Let the snackbar go away: it overlays the Save button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await scrollFormTo(tester, 'Save');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final rows = await harness.db.select(harness.db.medications).get();
      expect(rows.single.remindersEnabled, isFalse);
    },
    overrides: [
      notificationSchedulerProvider.overrideWithValue(schedulerDenying),
    ],
  );
}
