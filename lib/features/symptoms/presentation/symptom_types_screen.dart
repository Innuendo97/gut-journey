import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/widgets/text_input_dialog.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final allSymptomTypesProvider = StreamProvider.autoDispose<List<SymptomType>>(
  (ref) =>
      ref.watch(symptomRepositoryProvider).watchTypes(includeArchived: true),
);

/// Manage the symptom vocabulary: add custom types, archive/restore any
/// type. Archived types disappear from pickers but keep their history.
class SymptomTypesScreen extends ConsumerWidget {
  const SymptomTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final types = ref.watch(allSymptomTypesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageSymptomTypes)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addSymptomType),
        onPressed: () => unawaited(_addCustomType(context, ref)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final type in types)
            ListTile(
              title: Text(l10n.symptomTypeLabel(type)),
              subtitle: type.isArchived ? Text(l10n.archivedLabel) : null,
              trailing: TextButton(
                onPressed: () => unawaited(
                  ref
                      .read(symptomRepositoryProvider)
                      .setTypeArchived(type.id, isArchived: !type.isArchived),
                ),
                child: Text(
                  type.isArchived ? l10n.restoreAction : l10n.archiveAction,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addCustomType(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final values = await TextInputDialog.show(
      context,
      title: l10n.addSymptomType,
      fields: [TextInputField(label: l10n.symptomTypeName)],
    );
    final name = values?.first.trim() ?? '';
    if (name.isNotEmpty) {
      await ref.read(symptomRepositoryProvider).addCustomType(name);
    }
  }
}
