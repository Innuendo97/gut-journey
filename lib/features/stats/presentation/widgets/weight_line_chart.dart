import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/stats/presentation/chart_theme.dart';

/// Weight trend: a single line, so it wears the theme primary and needs no
/// legend (the section title names it).
class WeightLineChart extends StatelessWidget {
  const WeightLineChart({required this.range, required this.values, super.key});

  final DateRange range;
  final List<DailyValue> values;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    double dayIndex(LocalDay day) => range.start
        .toDateTime()
        .difference(day.toDateTime())
        .inDays
        .abs()
        .toDouble();

    final ys = [for (final value in values) value.value];
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    // Pad the y range so a flat weight doesn't hug the chart edges.
    final padding = ((maxY - minY) * 0.2).clamp(0.5, double.infinity);

    return LineChart(
      LineChartData(
        maxX: (range.lengthInDays - 1).toDouble(),
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: chartGrid(context),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: noAxisTitles,
          rightTitles: noAxisTitles,
          leftTitles: leftAxisTitles(context, reservedSize: 40),
          bottomTitles: dayAxisTitles(context, range),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            color: colorScheme.primary,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: values.length <= 31,
              getDotPainter: (spot, percent, bar, i) => FlDotCirclePainter(
                radius: 2.5,
                color: colorScheme.primary,
              ),
            ),
            spots: [
              for (final value in values)
                FlSpot(dayIndex(value.day), value.value),
            ],
          ),
        ],
      ),
    );
  }
}
