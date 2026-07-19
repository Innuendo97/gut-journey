import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/presentation/medication_quick_add_sheet.dart';
import 'package:gut_journey/features/nutrition/presentation/nutrition_providers.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// The day's numbers at a glance: estimated energy as the headline (when
/// tracked), then the compact water + medications row.
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
    final takenDoses = diaryDay.medicationIntakes
        .where((intake) => intake.status == IntakeStatus.taken)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          _KcalCard(day: diaryDay.day),
          _buildWaterMedsRow(
            context,
            ref,
            l10n,
            theme,
            goal,
            expectedDoses,
            takenDoses,
          ),
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
                borderRadius: BorderRadius.circular(16),
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

/// Estimated energy of the day — the headline of the summary. Hidden until
/// the user opts in, either by giving foods kcal estimates or by setting a
/// daily goal. Totals are estimates, never advice.
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

    final total = dayKcal?.round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionCardTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _headline(l10n, theme, total, goal),
                if (goal > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ((total ?? 0) / goal).clamp(0, 1).toDouble(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Big number, quiet unit (and goal). One Text widget so the full
  /// localized string stays findable and accessible as a whole.
  Widget _headline(
    AppLocalizations l10n,
    ThemeData theme,
    int? total,
    int goal,
  ) {
    final numberStyle = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    // Goal set but nothing kcal-bearing logged yet.
    if (total == null) return Text('—', style: numberStyle);

    final formatted = goal > 0
        ? l10n.nutritionKcalProgress(total, goal)
        : l10n.nutritionKcalValue(total);
    final number = '$total';
    if (!formatted.startsWith(number)) {
      return Text(formatted, style: numberStyle);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: number, style: numberStyle),
          TextSpan(
            text: formatted.substring(number.length),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
