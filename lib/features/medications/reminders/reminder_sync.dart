import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/medications/reminders/notification_scheduler.dart';
import 'package:gut_journey/features/medications/reminders/reminder_plan.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Keeps pending notifications in sync with the medication list: watched
/// at startup (fire-and-forget) and re-fired by every medication change,
/// since medicationsProvider is a stream over the table.
final reminderSyncProvider = Provider<void>((ref) {
  final medications = ref.watch(medicationsProvider).value;
  if (medications == null) return;
  final scheduler = ref.read(notificationSchedulerProvider);
  final today = LocalDay.fromDateTime(ref.read(clockProvider)());
  final l10n = _l10nFor(
    ref.watch(settingsProvider.select((settings) => settings.localeTag)),
  );
  final plan = planReminders(medications, today: today);
  unawaited(
    scheduler.sync(
      plan,
      ReminderStrings(
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        bodyForSlot: l10n.medicationReminderBody,
      ),
    ),
  );
});

/// Notification copy is resolved without a BuildContext: the chosen app
/// language when set, else the device locale, else English.
AppLocalizations _l10nFor(String? localeTag) {
  final locale = localeTag != null
      ? Locale(localeTag)
      : WidgetsBinding.instance.platformDispatcher.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (candidate) => candidate.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(
    supported ? Locale(locale.languageCode) : const Locale('en'),
  );
}
