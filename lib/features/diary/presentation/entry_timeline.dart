import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/widgets/delete_entry_with_undo.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/presentation/activity_quick_add_sheet.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/bowel/presentation/bowel_quick_add_sheet.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/presentation/meal_quick_add_sheet.dart';
import 'package:gut_journey/features/meals/presentation/meal_type_icon.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/sleep/presentation/sleep_quick_add_sheet.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/features/symptoms/presentation/symptom_quick_add_sheet.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';
import 'package:gut_journey/features/weight/presentation/weight_quick_add_sheet.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// One row of the day timeline, with everything needed to render, edit,
/// delete and restore it.
class _TimelineItem {
  const _TimelineItem({
    required this.id,
    required this.sortKey,
    required this.icon,
    required this.title,
    required this.delete,
    required this.restore,
    this.subtitle,
    this.timeLabel,
    this.onEdit,
  });

  final String id;
  final DateTime sortKey;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? timeLabel;
  final VoidCallback? onEdit;
  final Future<void> Function() delete;
  final Future<void> Function() restore;
}

/// Chronological list of everything logged on [diaryDay]: tap to edit,
/// swipe to delete — confirmed first, then still undoable.
class EntryTimeline extends ConsumerWidget {
  const EntryTimeline({required this.diaryDay, super.key});

  final DiaryDay diaryDay;

  /// A swipe is easy to trigger by accident while scrolling, so unlike the
  /// deliberate Delete buttons in the edit sheets it asks first. The undo
  /// snackbar stays as the second net.
  static Future<bool?> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildItems(context, ref)
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    return Column(
      children: [
        for (final item in items)
          Dismissible(
            key: ValueKey('timeline-${item.id}'),
            direction: DismissDirection.endToStart,
            background: ColoredBox(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            confirmDismiss: (_) async => await _confirmDelete(context) ?? false,
            onDismissed: (_) => deleteEntryWithUndo(
              context,
              delete: item.delete,
              restore: item.restore,
            ),
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
              trailing: item.timeLabel != null
                  ? Text(
                      item.timeLabel!,
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  : null,
              onTap: item.onEdit,
            ),
          ),
      ],
    );
  }

  List<_TimelineItem> _buildItems(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Repositories are resolved now, not inside the delete/restore closures:
    // undo fires from a SnackBar after this widget may have been unmounted,
    // when reading through `ref` would throw.
    final mealRepo = ref.read(mealRepositoryProvider);
    final symptomRepo = ref.read(symptomRepositoryProvider);
    final bowelRepo = ref.read(bowelRepositoryProvider);
    final weightRepo = ref.read(weightRepositoryProvider);
    final medicationRepo = ref.read(medicationRepositoryProvider);
    final waterRepo = ref.read(waterRepositoryProvider);
    final sleepRepo = ref.read(sleepRepositoryProvider);
    final activityRepo = ref.read(activityRepositoryProvider);
    final locale = Localizations.localeOf(context).toString();
    final timeFormat = DateFormat.Hm(locale);
    String timeOf(DateTime moment) => timeFormat.format(moment.toLocal());

    final symptomTypes = {
      for (final type
          in ref.watch(symptomTypesProvider).value ?? const <SymptomType>[])
        type.id: type,
    };
    final medications = {
      for (final med
          in ref.watch(activeMedicationsProvider).value ?? const <Medication>[])
        med.id: med,
    };
    final day = diaryDay.day;

    return [
      for (final meal in diaryDay.meals)
        _TimelineItem(
          id: meal.id,
          sortKey: meal.occurredAt,
          icon: mealTypeIcon(meal.type),
          title: l10n.mealTypeLabel(meal.type),
          subtitle: meal.items.isEmpty
              ? meal.notes
              : meal.items.map((i) => i.food.name).join(', '),
          timeLabel: timeOf(meal.occurredAt),
          onEdit: () => MealQuickAddSheet.show(
            context,
            day: day,
            existing: meal,
          ),
          delete: () => mealRepo.deleteMeal(meal.id),
          restore: () async {
            await mealRepo.createMeal(
              type: meal.type,
              occurredAt: meal.occurredAt,
              items: [
                for (final item in meal.items)
                  MealItemInput.existing(
                    foodItemId: item.food.id,
                    portionDescription: item.portionDescription,
                    quantity: item.quantity,
                  ),
              ],
              notes: meal.notes,
            );
          },
        ),
      for (final symptom in diaryDay.symptoms)
        _TimelineItem(
          id: symptom.id,
          sortKey: symptom.occurredAt,
          icon: Icons.healing_outlined,
          title: switch (symptomTypes[symptom.symptomTypeId]) {
            final type? => l10n.symptomTypeLabel(type),
            null => l10n.quickAddSymptom,
          },
          subtitle: l10n.intensityOutOf10(symptom.intensity),
          timeLabel: timeOf(symptom.occurredAt),
          onEdit: () => SymptomQuickAddSheet.show(
            context,
            day: day,
            existing: symptom,
          ),
          delete: () => symptomRepo.deleteEntry(symptom.id),
          restore: () async {
            await symptomRepo.addEntry(
              symptomTypeId: symptom.symptomTypeId,
              intensity: symptom.intensity,
              occurredAt: symptom.occurredAt,
              durationMinutes: symptom.durationMinutes,
              notes: symptom.notes,
            );
          },
        ),
      for (final movement in diaryDay.bowelMovements)
        _TimelineItem(
          id: movement.id,
          sortKey: movement.occurredAt,
          icon: Icons.wc_outlined,
          title: l10n.bristolTitle(movement.bristolType),
          subtitle: l10n.bristolDescription(movement.bristolType),
          timeLabel: timeOf(movement.occurredAt),
          onEdit: () => BowelQuickAddSheet.show(
            context,
            day: day,
            existing: movement,
          ),
          delete: () => bowelRepo.delete(movement.id),
          restore: () async {
            await bowelRepo.add(
              bristolType: movement.bristolType,
              occurredAt: movement.occurredAt,
              urgency: movement.urgency,
              pain: movement.pain,
              blood: movement.blood,
              mucus: movement.mucus,
              incompleteEvacuation: movement.incompleteEvacuation,
              notes: movement.notes,
            );
          },
        ),
      for (final weight in diaryDay.weightEntries)
        _TimelineItem(
          id: weight.id,
          sortKey: weight.occurredAt,
          icon: Icons.monitor_weight_outlined,
          title: l10n.weightKgValue(weight.weightKg.toStringAsFixed(1)),
          timeLabel: timeOf(weight.occurredAt),
          onEdit: () => WeightQuickAddSheet.show(
            context,
            day: day,
            existing: weight,
          ),
          delete: () => weightRepo.delete(weight.id),
          restore: () async {
            await weightRepo.add(
              weightKg: weight.weightKg,
              occurredAt: weight.occurredAt,
              notes: weight.notes,
            );
          },
        ),
      for (final intake in diaryDay.medicationIntakes)
        _TimelineItem(
          id: intake.id,
          sortKey: intake.occurredAt,
          icon: Icons.medication_outlined,
          title:
              medications[intake.medicationId]?.name ?? l10n.quickAddMedication,
          subtitle: intake.scheduledTime != null
              ? l10n.takenAt(intake.scheduledTime!)
              : l10n.takenStatus,
          timeLabel: timeOf(intake.occurredAt),
          delete: () => medicationRepo.deleteIntake(intake.id),
          restore: () async {
            await medicationRepo.logIntake(
              medicationId: intake.medicationId,
              status: intake.status,
              occurredAt: intake.occurredAt,
              scheduledTime: intake.scheduledTime,
              notes: intake.notes,
            );
          },
        ),
      for (final water in diaryDay.waterIntakes)
        _TimelineItem(
          id: water.id,
          sortKey: water.occurredAt,
          icon: Icons.water_drop_outlined,
          title: '${water.amountMl} ml',
          timeLabel: timeOf(water.occurredAt),
          delete: () => waterRepo.delete(water.id),
          restore: () async {
            await waterRepo.add(
              amountMl: water.amountMl,
              occurredAt: water.occurredAt,
              notes: water.notes,
            );
          },
        ),
      if (diaryDay.sleep case final sleep?)
        _TimelineItem(
          id: sleep.id,
          sortKey: day.toDateTime(),
          icon: Icons.bedtime_outlined,
          title: l10n.sleepHoursMinutes(
            sleep.durationMinutes ~/ 60,
            sleep.durationMinutes % 60,
          ),
          subtitle: switch (sleep.quality) {
            // Readable and screen-reader friendly, unlike a run of stars.
            final quality? => l10n.sleepQualityValue(quality),
            null => null,
          },
          onEdit: () => SleepQuickAddSheet.show(
            context,
            day: day,
            existing: sleep,
          ),
          delete: () => sleepRepo.deleteForDay(day),
          restore: () async {
            await sleepRepo.upsertForDay(
              day: day,
              durationMinutes: sleep.durationMinutes,
              bedAt: sleep.bedAt,
              wokeAt: sleep.wokeAt,
              quality: sleep.quality,
              notes: sleep.notes,
            );
          },
        ),
      for (final activity in diaryDay.activities)
        _TimelineItem(
          id: activity.id,
          sortKey: activity.occurredAt,
          icon: Icons.directions_run_outlined,
          title: activity.name,
          subtitle:
              '${l10n.minutesShort(activity.durationMinutes)} · '
              '${l10n.effortName(activity.effort)}',
          timeLabel: timeOf(activity.occurredAt),
          onEdit: () => ActivityQuickAddSheet.show(
            context,
            day: day,
            existing: activity,
          ),
          delete: () => activityRepo.delete(activity.id),
          restore: () async {
            await activityRepo.add(
              name: activity.name,
              durationMinutes: activity.durationMinutes,
              effort: activity.effort,
              occurredAt: activity.occurredAt,
              notes: activity.notes,
            );
          },
        ),
    ];
  }
}
