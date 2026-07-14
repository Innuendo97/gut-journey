import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/stats/presentation/chart_theme.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Average symptom intensity per day, one line per symptom type. Hues come
/// from the fixed categorical palette; at most [maxChartSeries] series are
/// drawn (the most logged ones), never a cycled 5th hue.
class IntensityLineChart extends StatelessWidget {
  const IntensityLineChart({
    required this.range,
    required this.series,
    required this.typesById,
    super.key,
  });

  final DateRange range;

  /// Symptom type id → daily averages, ordered by how often each type was
  /// logged (most frequent first).
  final Map<String, List<DailyValue>> series;
  final Map<String, SymptomType> typesById;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = categoricalSeriesColors(Theme.of(context).brightness);
    final drawn = series.entries.take(maxChartSeries).toList();

    double dayIndex(LocalDay day) => range.start
        .toDateTime()
        .difference(day.toDateTime())
        .inDays
        .abs()
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              maxY: 10,
              maxX: (range.lengthInDays - 1).toDouble(),
              gridData: chartGrid(context),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: noAxisTitles,
                rightTitles: noAxisTitles,
                leftTitles: leftAxisTitles(context, reservedSize: 28),
                bottomTitles: dayAxisTitles(context, range),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      Theme.of(context).colorScheme.inverseSurface,
                ),
              ),
              lineBarsData: [
                for (final (index, entry) in drawn.indexed)
                  LineChartBarData(
                    color: colors[index],
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: range.lengthInDays <= 31,
                      getDotPainter: (spot, percent, bar, i) =>
                          FlDotCirclePainter(
                            radius: 2.5,
                            color: colors[index],
                          ),
                    ),
                    spots: [
                      for (final value in entry.value)
                        FlSpot(dayIndex(value.day), value.value),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend: identity is never color-alone — a labeled dot per series.
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final (index, entry) in drawn.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[index],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    switch (typesById[entry.key]) {
                      final type? => l10n.symptomTypeLabel(type),
                      null => entry.key,
                    },
                    style: chartLabelStyle(context),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
