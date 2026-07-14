import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gut_journey/features/stats/presentation/chart_theme.dart';

/// Count of bowel movements per Bristol type (1–7). Ordinal magnitude →
/// a single hue.
class BristolBarChart extends StatelessWidget {
  const BristolBarChart({required this.counts, super.key});

  /// Bristol type (1–7) → count.
  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        gridData: chartGrid(context),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: noAxisTitles,
          rightTitles: noAxisTitles,
          leftTitles: leftAxisTitles(context, reservedSize: 28),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${value.round()}',
                  style: chartLabelStyle(context),
                ),
              ),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
          ),
        ),
        barGroups: [
          for (var type = 1; type <= 7; type++)
            BarChartGroupData(
              x: type,
              barRods: [
                BarChartRodData(
                  toY: (counts[type] ?? 0).toDouble(),
                  width: 18,
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
