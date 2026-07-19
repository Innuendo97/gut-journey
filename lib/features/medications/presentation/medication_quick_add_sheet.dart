import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Unlike the other sheets this one acts instantly: tapping a dose logs it
/// right away, tapping it again removes it. No save button.
class MedicationQuickAddSheet extends ConsumerWidget {
  const MedicationQuickAddSheet({required this.day, super.key});

  final LocalDay day;

  static Future<void> show(BuildContext context, {required LocalDay day}) =>
      showQuickAddSheet(
        context: context,
        builder: (_) => MedicationQuickAddSheet(day: day),
      );

  DateTime _occurredAt(WidgetRef ref, String? slot) {
    final now = ref.read(clockProvider)();
    if (LocalDay.fromDateTime(now) == day) return now;
    // Back-filling: anchor to the slot time, or midday for as-needed doses.
    final parts = slot?.split(':');
    final hour = parts != null ? int.tryParse(parts[0]) ?? 12 : 12;
    final minute = parts != null && parts.length > 1
        ? int.tryParse(parts[1]) ?? 0
        : 0;
    return day.toDateTime().add(Duration(hours: hour, minutes: minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final medications = ref.watch(medicationsOnDayProvider(day));
    final diaryDay = ref.watch(diaryDayProvider(day)).value;
    final intakes = diaryDay?.medicationIntakes ?? const <MedicationIntake>[];
    final repo = ref.read(medicationRepositoryProvider);

    final scheduled = [
      for (final med in medications)
        if (med.expectedSlotsOn(day).isNotEmpty) med,
    ];
    final asNeeded = [
      for (final med in medications)
        if (med.scheduleType == ScheduleType.asNeeded) med,
    ];

    return SheetScaffold(
      title: l10n.medicationSheetTitle,
      children: [
        if (medications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(l10n.noMedications),
          ),
        if (scheduled.isNotEmpty) ...[
          Text(
            l10n.scheduledSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final med in scheduled)
            _ScheduledMedicationTile(
              medication: med,
              intakes: intakes,
              onSetStatus: (slot, current, target) async {
                // Re-applying the same status is a no-op, not a re-log.
                if (current?.status == target) return;
                if (current != null) await repo.deleteIntake(current.id);
                if (target != null) {
                  await repo.logIntake(
                    medicationId: med.id,
                    status: target,
                    occurredAt: _occurredAt(ref, slot),
                    scheduledTime: slot,
                  );
                }
              },
            ),
          const SizedBox(height: 16),
        ],
        if (asNeeded.isNotEmpty) ...[
          Text(
            l10n.asNeededSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final med in asNeeded)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(med.name),
              subtitle: med.dosage != null ? Text(med.dosage!) : null,
              trailing: FilledButton.tonal(
                onPressed: () => repo.logIntake(
                  medicationId: med.id,
                  status: IntakeStatus.taken,
                  occurredAt: _occurredAt(ref, null),
                ),
                child: Text(l10n.takeAction),
              ),
            ),
        ],
        const Divider(),
        TextButton.icon(
          icon: const Icon(Icons.settings_outlined),
          label: Text(l10n.manageMedications),
          onPressed: () {
            Navigator.of(context).pop();
            context.go(AppRoutes.moreMedications);
          },
        ),
      ],
    );
  }
}

class _ScheduledMedicationTile extends StatelessWidget {
  const _ScheduledMedicationTile({
    required this.medication,
    required this.intakes,
    required this.onSetStatus,
  });

  final Medication medication;
  final List<MedicationIntake> intakes;

  /// Moves a slot to the target status — null clears it. The second
  /// argument is the intake occupying the slot right now, if any.
  final void Function(
    String slot,
    MedicationIntake? current,
    IntakeStatus? target,
  )
  onSetStatus;

  /// The intake covering a slot, if any: prefer an exact slot match, then
  /// any unassigned taken dose of this medication.
  MedicationIntake? _intakeForSlot(String slot, Set<String> claimed) {
    for (final intake in intakes) {
      if (intake.medicationId != medication.id) continue;
      if (claimed.contains(intake.id)) continue;
      if (intake.scheduledTime == slot) return intake;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final claimed = <String>{};

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(medication.name),
      subtitle: medication.dosage != null ? Text(medication.dosage!) : null,
      trailing: Wrap(
        spacing: 4,
        children: [
          for (final slot in medication.scheduledTimes)
            Builder(
              builder: (context) {
                final intake = _intakeForSlot(slot, claimed);
                if (intake != null) claimed.add(intake.id);
                final skipped = intake?.status == IntakeStatus.skipped;
                // Tap keeps the quick path (taken/clear); long-press opens
                // the menu with the skipped option.
                return MenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.check),
                      onPressed: () =>
                          onSetStatus(slot, intake, IntakeStatus.taken),
                      child: Text(l10n.takenStatus),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.block),
                      onPressed: () =>
                          onSetStatus(slot, intake, IntakeStatus.skipped),
                      child: Text(l10n.skippedStatus),
                    ),
                    if (intake != null)
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.clear),
                        onPressed: () => onSetStatus(slot, intake, null),
                        child: Text(l10n.medicationSlotClear),
                      ),
                  ],
                  builder: (context, controller, _) => GestureDetector(
                    onLongPress: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    // No tooltip: its long-press recognizer would swallow
                    // the long-press that opens the status menu.
                    child: FilterChip(
                      label: Text(slot),
                      selected: intake != null,
                      avatar: skipped ? const Icon(Icons.block) : null,
                      showCheckmark: !skipped,
                      onSelected: (selected) {
                        if (selected) {
                          if (intake == null) {
                            onSetStatus(slot, null, IntakeStatus.taken);
                          }
                        } else {
                          onSetStatus(slot, intake, null);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
