import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/stats/presentation/chart_theme.dart';

/// One bar per day of [range] — the workhorse for water, sleep and activity.
/// Single measure → single hue (the theme primary), with an optional dashed
/// [goal] reference line.
class DailyBarsChart extends StatelessWidget {
  const DailyBarsChart({
    required this.range,
    required this.values,
    this.goal,
    super.key,
  });

  final DateRange range;
  final List<DailyValue> values;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final byDay = {for (final value in values) value.day: value.value};
    final days = range.days;
    final barWidth = (240 / days.length).clamp(2.0, 14.0);

    return BarChart(
      BarChartData(
        gridData: chartGrid(context),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: noAxisTitles,
          rightTitles: noAxisTitles,
          leftTitles: leftAxisTitles(context),
          bottomTitles: dayAxisTitles(context, range),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
          ),
        ),
        extraLinesData: goal == null
            ? null
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goal!,
                    color: colorScheme.onSurfaceVariant,
                    strokeWidth: 1,
                    dashArray: const [6, 4],
                  ),
                ],
              ),
        barGroups: [
          for (final (index, day) in days.indexed)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: byDay[day] ?? 0,
                  width: barWidth,
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
