import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/text_input_dialog.dart';
import 'package:gut_journey/features/backup/data/backup_files.dart';
import 'package:gut_journey/features/backup/data/backup_repository.dart';
import 'package:gut_journey/features/report/presentation/report_export_sheet.dart';
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
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupExportDb),
            subtitle: Text(l10n.backupExportDbSubtitle),
            onTap: () => unawaited(_exportDatabase(context, ref)),
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(l10n.backupExportJson),
            subtitle: Text(l10n.backupExportJsonSubtitle),
            onTap: () => unawaited(_exportJson(context, ref)),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l10n.reportExportTile),
            subtitle: Text(l10n.reportExportTileSubtitle),
            onTap: () => unawaited(showReportExportSheet(context)),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.backupRestore),
            subtitle: Text(l10n.backupRestoreSubtitle),
            onTap: () => unawaited(_restoreBackup(context, ref)),
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

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final day = LocalDay.fromDateTime(ref.read(clockProvider)());
    final bytes = await ref
        .read(backupRepositoryProvider)
        .exportDatabaseBytes();
    final saved = await ref
        .read(backupFilesProvider)
        .saveAs(fileName: 'gut-journey-backup-${day.value}.db', bytes: bytes);
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupSaved)));
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final day = LocalDay.fromDateTime(ref.read(clockProvider)());
    final json = await ref.read(backupRepositoryProvider).exportJsonString();
    final saved = await ref
        .read(backupFilesProvider)
        .saveAs(
          fileName: 'gut-journey-export-${day.value}.json',
          bytes: utf8.encode(json),
        );
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportSaved)));
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = await ref.read(backupFilesProvider).pickBackupFile();
    if (path == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreConfirmTitle),
        content: Text(l10n.backupRestoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(backupRepositoryProvider).restoreDatabase(path);
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupRestoreDone)));
    } on BackupException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (e.error) {
            BackupError.notABackup => l10n.backupErrorInvalid,
            BackupError.newerSchema => l10n.backupErrorNewer,
          }),
        ),
      );
    }
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
