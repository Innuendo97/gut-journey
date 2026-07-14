import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final StreamProvider<List<Medication>> allMedicationsProvider =
    StreamProvider.autoDispose<List<Medication>>(
      (ref) => ref.watch(medicationRepositoryProvider).watchAll(),
    );

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final medications = ref.watch(allMedicationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.medicationsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addMedication),
        onPressed: () => context.go(AppRoutes.moreMedicationsNew),
      ),
      body: switch (medications) {
        AsyncValue(value: final items?) when items.isEmpty => EmptyState(
          icon: Icons.medication_outlined,
          title: l10n.noMedications,
        ),
        AsyncValue(value: final items?) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final med = items[index];
            final schedule = med.scheduleType == ScheduleType.asNeeded
                ? l10n.scheduleAsNeeded
                : med.scheduledTimes.join(' · ');
            return ListTile(
              leading: Icon(
                Icons.medication_outlined,
                color: med.isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(med.name),
              subtitle: Text(
                [
                  if (med.dosage != null) med.dosage!,
                  schedule,
                  if (!med.isActive) l10n.inactiveLabel,
                ].join(' · '),
              ),
              onTap: () => context.go(
                AppRoutes.moreMedicationEdit(med.id),
                extra: med,
              ),
              trailing: Switch(
                value: med.isActive,
                onChanged: (value) => unawaited(
                  ref
                      .read(medicationRepositoryProvider)
                      .setActive(
                        med.id,
                        isActive: value,
                      ),
                ),
              ),
            );
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
