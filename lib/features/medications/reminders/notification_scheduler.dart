import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/features/medications/reminders/local_notification_scheduler.dart';
import 'package:gut_journey/features/medications/reminders/reminder_plan.dart';

/// User-facing copy the scheduler needs; resolved by the caller so the
/// scheduler itself stays free of localization lookups.
class ReminderStrings {
  const ReminderStrings({
    required this.channelName,
    required this.channelDescription,
    required this.bodyForSlot,
  });

  final String channelName;
  final String channelDescription;
  final String Function(String slot) bodyForSlot;
}

/// Platform-free seam for reminder notifications: the real Android
/// implementation lives in [LocalNotificationScheduler]; everything else
/// (host tests, unsupported platforms) gets the no-op.
abstract interface class NotificationScheduler {
  /// Asks for notification permission (Android 13+). True when granted.
  Future<bool> requestPermission();

  /// Makes the pending notifications match [plan] exactly.
  Future<void> sync(List<PlannedReminder> plan, ReminderStrings strings);
}

class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(
    List<PlannedReminder> plan,
    ReminderStrings strings,
  ) async {}
}

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  if (!kIsWeb && Platform.isAndroid) return LocalNotificationScheduler();
  return const NoopNotificationScheduler();
});
