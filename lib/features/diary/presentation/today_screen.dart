import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/activity/presentation/activity_quick_add_sheet.dart';
import 'package:gut_journey/features/bowel/presentation/bowel_quick_add_sheet.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/diary/presentation/diary_day_body.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/meals/presentation/meal_quick_add_sheet.dart';
import 'package:gut_journey/features/medications/presentation/medication_quick_add_sheet.dart';
import 'package:gut_journey/features/nutrition/presentation/nutrition_providers.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/features/sleep/presentation/sleep_quick_add_sheet.dart';
import 'package:gut_journey/features/symptoms/presentation/symptom_quick_add_sheet.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/presentation/weight_quick_add_sheet.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final day = ref.watch(selectedDayProvider);
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(selectedDayProvider.notifier).previousDay(),
        ),
        title: Text(_dayTitle(context, day, today)),
        centerTitle: true,
        actions: [
          if (day != today)
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: l10n.todayLabel,
              onPressed: () =>
                  ref.read(selectedDayProvider.notifier).goToToday(),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: day.isBefore(today)
                ? () => ref.read(selectedDayProvider.notifier).nextDay()
                : null,
          ),
        ],
      ),
      body: DiaryDayBody(day: day),
    );
  }

  String _dayTitle(BuildContext context, LocalDay day, LocalDay today) {
    final l10n = AppLocalizations.of(context);
    if (day == today) return l10n.todayLabel;
    if (day == today.previous) return l10n.yesterdayLabel;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMMEd(locale).format(day.toDateTime());
  }
}

/// The always-visible row of one-tap entry points — the core promise that
/// logging anything takes seconds.
class QuickAddBar extends ConsumerWidget {
  const QuickAddBar({required this.day, super.key});

  final LocalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final buttons = [
      (
        Icons.restaurant_outlined,
        l10n.quickAddMeal,
        () {
          unawaited(MealQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.healing_outlined,
        l10n.quickAddSymptom,
        () {
          unawaited(SymptomQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.wc_outlined,
        l10n.quickAddBowel,
        () {
          unawaited(BowelQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.water_drop_outlined,
        l10n.quickAddWater,
        () {
          unawaited(_addWater(ref));
        },
      ),
      (
        Icons.monitor_weight_outlined,
        l10n.quickAddWeight,
        () {
          unawaited(WeightQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.medication_outlined,
        l10n.quickAddMedication,
        () {
          unawaited(MedicationQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.bedtime_outlined,
        l10n.quickAddSleep,
        () {
          final diaryDay = ref.read(diaryDayProvider(day)).value;
          unawaited(
            SleepQuickAddSheet.show(
              context,
              day: day,
              existing: diaryDay?.sleep,
            ),
          );
        },
      ),
      (
        Icons.directions_run_outlined,
        l10n.quickAddActivity,
        () {
          unawaited(ActivityQuickAddSheet.show(context, day: day));
        },
      ),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: buttons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final (icon, label, onTap) = buttons[index];
          return _QuickAddButton(icon: icon, label: label, onTap: onTap);
        },
      ),
    );
  }

  Future<void> _addWater(WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final occurredAt = LocalDay.fromDateTime(now) == day
        ? now
        : day.toDateTime().add(const Duration(hours: 12));
    return ref
        .read(waterRepositoryProvider)
        .add(amountMl: 250, occurredAt: occurredAt);
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Compact water + medications (and, when tracked, estimated kcal)
/// overview for the day.
class DaySummaryStrip extends ConsumerWidget {
  const DaySummaryStrip({required this.diaryDay, super.key});

  final DiaryDay diaryDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goal = ref.watch(settingsProvider).waterGoalMl;
    final medications = ref.watch(medicationsOnDayProvider(diaryDay.day));
    final expectedDoses = medications.fold<int>(
      0,
      (sum, med) => sum + med.expectedSlotsOn(diaryDay.day).length,
    );
    final takenDoses = diaryDay.medicationIntakes.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          _buildWaterMedsRow(
            context,
            ref,
            l10n,
            theme,
            goal,
            expectedDoses,
            takenDoses,
          ),
          _KcalCard(day: diaryDay.day),
        ],
      ),
    );
  }

  Widget _buildWaterMedsRow(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    int goal,
    int expectedDoses,
    int takenDoses,
  ) {
    return
    // IntrinsicHeight keeps the two cards equal-height inside the
    // unbounded-height ListView.
    IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.waterCardTitle,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.waterProgress(diaryDay.totalWaterMl, goal),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: goal == 0
                          ? 0
                          : (diaryDay.totalWaterMl / goal)
                                .clamp(0, 1)
                                .toDouble(),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => unawaited(
                          ref
                              .read(waterRepositoryProvider)
                              .add(
                                amountMl: 250,
                                occurredAt: _waterMoment(ref),
                              ),
                        ),
                        child: Text(l10n.addWater250),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => unawaited(
                  MedicationQuickAddSheet.show(context, day: diaryDay.day),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.medsCardTitle,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expectedDoses == 0 && takenDoses == 0
                            ? l10n.medsNoneScheduled
                            : l10n.medsProgress(takenDoses, expectedDoses),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _waterMoment(WidgetRef ref) {
    final now = ref.read(clockProvider)();
    return LocalDay.fromDateTime(now) == diaryDay.day
        ? now
        : diaryDay.day.toDateTime().add(const Duration(hours: 12));
  }
}

/// Estimated energy of the day. Hidden until the user opts in — either by
/// giving foods kcal estimates or by setting a daily goal; the progress
/// bar needs the goal. Totals are estimates, never advice.
class _KcalCard extends ConsumerWidget {
  const _KcalCard({required this.day});

  final LocalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goal = ref.watch(settingsProvider).kcalGoal;
    final dayKcal = ref.watch(dayKcalProvider(day)).value;
    if (dayKcal == null && goal <= 0) return const SizedBox.shrink();

    final total = (dayKcal ?? 0).round();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionCardTitle,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  goal > 0
                      ? l10n.nutritionKcalProgress(total, goal)
                      : l10n.nutritionKcalValue(total),
                  style: theme.textTheme.titleSmall,
                ),
                if (goal > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (total / goal).clamp(0, 1).toDouble(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
