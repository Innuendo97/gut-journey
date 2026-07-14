import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/widgets/text_input_dialog.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.languageLabel),
            trailing: DropdownButton<String>(
              value: settings.localeTag ?? 'system',
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.languageSystem),
                ),
                // Language names are shown in their own language on purpose.
                const DropdownMenuItem(value: 'en', child: Text('English')),
                const DropdownMenuItem(value: 'it', child: Text('Italiano')),
              ],
              onChanged: (value) => unawaited(
                ref
                    .read(settingsProvider.notifier)
                    .setLocaleTag(value == 'system' ? null : value),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: Text(l10n.waterGoalSetting),
            subtitle: Text(l10n.waterGoalValue(settings.waterGoalMl)),
            onTap: () => unawaited(_editWaterGoal(context, ref, settings)),
          ),
          ListTile(
            leading: const Icon(Icons.healing_outlined),
            title: Text(l10n.manageSymptomTypes),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreSettingsSymptoms),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.medical_information_outlined),
            title: Text(l10n.disclaimerSetting),
            onTap: () => unawaited(
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.disclaimerTitle),
                  content: Text(l10n.disclaimerBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.licensesSetting),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editWaterGoal(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final values = await TextInputDialog.show(
      context,
      title: l10n.waterGoalSetting,
      fields: [
        TextInputField(
          label: l10n.waterGoalSetting,
          initialValue: settings.waterGoalMl.toString(),
          keyboardType: TextInputType.number,
          suffixText: 'ml',
        ),
      ],
    );
    final goal = int.tryParse(values?.first.trim() ?? '');
    if (goal != null && goal > 0) {
      await ref.read(settingsProvider.notifier).setWaterGoalMl(goal);
    }
  }
}
