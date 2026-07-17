import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/report/presentation/report_export_sheet.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/stats/presentation/stats_providers.dart';
import 'package:gut_journey/features/stats/presentation/widgets/bristol_bar_chart.dart';
import 'package:gut_journey/features/stats/presentation/widgets/daily_bars_chart.dart';
import 'package:gut_journey/features/stats/presentation/widgets/intensity_line_chart.dart';
import 'package:gut_journey/features/stats/presentation/widgets/weight_line_chart.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final range = ref.watch(statsRangeProvider);
    final period = ref.watch(statsPeriodDaysProvider);

    final typesById = {
      for (final type
          in ref.watch(symptomTypesProvider).value ?? const <SymptomType>[])
        type.id: type,
    };
    final frequency =
        ref.watch(symptomFrequencyStatsProvider(range)).value ?? const {};
    final intensity =
        ref.watch(symptomIntensityStatsProvider(range)).value ?? const {};
    final bristol =
        ref.watch(bristolDistributionStatsProvider(range)).value ?? const {};
    final weight = ref.watch(weightStatsProvider(range)).value ?? const [];
    final water = ref.watch(waterStatsProvider(range)).value ?? const [];
    final sleep = ref.watch(sleepStatsProvider(range)).value ?? const [];
    final activity = ref.watch(activityStatsProvider(range)).value ?? const [];
    final adherence =
        ref.watch(adherenceStatsProvider(range)).value ?? const [];
    final waterGoal = ref.watch(settingsProvider).waterGoalMl;

    // Order intensity series by how often each symptom was logged, so the
    // chart's top-N cut keeps the most relevant ones.
    final orderedIntensity = {
      for (final id in frequency.keys) id: ?intensity[id],
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabStats),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.reportExportAction,
            onPressed: () => unawaited(
              showReportExportSheet(context, initialDays: period),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: [
                for (final days in StatsPeriodNotifier.options)
                  ButtonSegment(
                    value: days,
                    label: Text(l10n.statsPeriodDays(days)),
                  ),
              ],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(statsPeriodDaysProvider.notifier).days =
                      selection.first,
            ),
          ),
          const SizedBox(height: 8),
          _ChartSection(
            title: l10n.sectionSymptomIntensity,
            annotation: l10n.sectionSymptomIntensitySubtitle,
            isEmpty: orderedIntensity.isEmpty,
            height: 230,
            child: IntensityLineChart(
              range: range,
              series: orderedIntensity,
              typesById: typesById,
            ),
          ),
          _ChartSection(
            title: l10n.sectionSymptomFrequency,
            isEmpty: frequency.isEmpty,
            child: _FrequencyRows(frequency: frequency, typesById: typesById),
          ),
          _ChartSection(
            title: l10n.sectionBristol,
            annotation: bristol.isEmpty
                ? null
                : l10n.bristolNormalShare(_normalBristolShare(bristol)),
            isEmpty: bristol.isEmpty,
            height: 180,
            child: BristolBarChart(counts: bristol),
          ),
          _ChartSection(
            title: l10n.sectionWeight,
            annotation: weight.isEmpty ? null : _weightSummary(l10n, weight),
            isEmpty: weight.isEmpty,
            height: 200,
            child: WeightLineChart(range: range, values: weight),
          ),
          _ChartSection(
            title: l10n.sectionWater,
            annotation: '${l10n.waterGoalLegend}: $waterGoal ml',
            isEmpty: water.isEmpty,
            height: 180,
            child: DailyBarsChart(
              range: range,
              values: water,
              goal: waterGoal.toDouble(),
            ),
          ),
          _ChartSection(
            title: l10n.sectionSleep,
            annotation: sleep.isEmpty ? null : _sleepSummary(l10n, sleep),
            isEmpty: sleep.isEmpty,
            height: 180,
            child: DailyBarsChart(
              range: range,
              values: [
                for (final value in sleep)
                  DailyValue(value.day, value.value / 60),
              ],
            ),
          ),
          _ChartSection(
            title: l10n.sectionActivity,
            isEmpty: activity.isEmpty,
            height: 180,
            child: DailyBarsChart(range: range, values: activity),
          ),
          _ChartSection(
            title: l10n.sectionAdherence,
            isEmpty: !adherence.any((pair) => pair.$2.expectedDoses > 0),
            child: _AdherenceRows(adherence: adherence),
          ),
        ],
      ),
    );
  }

  static int _normalBristolShare(Map<int, int> counts) {
    final total = counts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return 0;
    final normal = (counts[3] ?? 0) + (counts[4] ?? 0);
    return (normal * 100 / total).round();
  }

  static String _weightSummary(
    AppLocalizations l10n,
    List<DailyValue> values,
  ) {
    final ys = [for (final value in values) value.value];
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    final avg = ys.reduce((a, b) => a + b) / ys.length;
    return l10n.weightMinAvgMax(
      min.toStringAsFixed(1),
      avg.toStringAsFixed(1),
      max.toStringAsFixed(1),
    );
  }

  static String _sleepSummary(
    AppLocalizations l10n,
    List<DailyValue> values,
  ) {
    final totalMinutes = values.fold<double>(0, (sum, v) => sum + v.value);
    final avg = (totalMinutes / values.length).round();
    return l10n.sleepAverage(avg ~/ 60, avg % 60);
  }
}

/// Card wrapper every section shares: title, optional annotation, and an
/// empty state when there's nothing to draw yet.
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.isEmpty,
    required this.child,
    this.annotation,
    this.height,
  });

  final String title;
  final String? annotation;
  final bool isEmpty;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (annotation != null && !isEmpty) ...[
              const SizedBox(height: 2),
              Text(
                annotation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isEmpty)
              Text(
                AppLocalizations.of(context).statsEmptySection,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (height != null)
              SizedBox(height: height, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}

/// One stat row per scheduled medication: taken/expected ratio over the
/// period. As-needed medications have no expectation and are skipped.
class _AdherenceRows extends StatelessWidget {
  const _AdherenceRows({required this.adherence});

  final List<(Medication, AdherenceSummary)> adherence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        for (final (medication, summary) in adherence)
          if (summary.ratio case final ratio?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          medication.name,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        l10n.adherencePercent((ratio * 100).round()),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.medsProgress(
                      summary.takenDoses,
                      summary.expectedDoses,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Symptom frequency as labeled rows with proportional bars — counts per
/// category read better as a list than as a rotated-label bar chart.
class _FrequencyRows extends StatelessWidget {
  const _FrequencyRows({required this.frequency, required this.typesById});

  final Map<String, int> frequency;
  final Map<String, SymptomType> typesById;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maxCount = frequency.values.fold(1, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final entry in frequency.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    switch (typesById[entry.key]) {
                      final type? => l10n.symptomTypeLabel(type),
                      null => entry.key,
                    },
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      minHeight: 10,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
