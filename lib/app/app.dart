import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/app/theme/app_theme.dart';
import 'package:gut_journey/features/medications/data/medication_upgrade.dart';
import 'package:gut_journey/features/medications/reminders/reminder_sync.dart';
import 'package:gut_journey/features/registry/data/registry_upgrade.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class GutJourneyApp extends ConsumerWidget {
  const GutJourneyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fire-and-forget startup work; the UI never waits on it.
    ref
      ..watch(registryUpgradeProvider)
      ..watch(medicationUpgradeProvider)
      ..watch(reminderSyncProvider);
    final router = ref.watch(routerProvider);
    final localeTag = ref.watch(
      settingsProvider.select((settings) => settings.localeTag),
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      // null follows the system locale.
      locale: localeTag == null ? null : Locale(localeTag),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    );
  }
}
