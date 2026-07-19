import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:gut_journey/features/medications/reminders/notification_scheduler.dart';
import 'package:gut_journey/features/medications/reminders/reminder_plan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android implementation on flutter_local_notifications: lazily
/// initializes the plugin and the timezone database, then mirrors each
/// plan with cancelAll + zonedSchedule. Reboots are covered by the
/// plugin's ScheduledNotificationBootReceiver (declared in the manifest).
class LocalNotificationScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Exception {
      // Exotic zone the tz database doesn't know: fire in UTC rather than
      // not at all.
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> sync(List<PlannedReminder> plan, ReminderStrings strings) async {
    await _ensureInitialized();
    // Exact when the special permission is already there, otherwise
    // inexact (±15 min) — never worth its own permission prompt.
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders',
        strings.channelName,
        channelDescription: strings.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final reminder in plan) {
      final parts = reminder.slot.split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final day = reminder.day;
      tz.TZDateTime when;
      if (day == null) {
        when = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      } else {
        final date = day.toDateTime();
        when = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        if (!when.isAfter(now)) continue;
      }

      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.medicationName,
        body: strings.bodyForSlot(reminder.slot),
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: day == null ? DateTimeComponents.time : null,
      );
    }
  }
}
