import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:intl/intl.dart';

/// Categorical palette for multi-series charts (symptom lines), assigned in
/// fixed slot order, never cycled. Values come from a CVD-validated palette
/// (worst adjacent ΔE 24.2 light / 10.3 dark); the dark column is the same
/// hues re-stepped for dark surfaces, not an automatic flip.
const _categoricalLight = [
  Color(0xFF2A78D6), // blue
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // yellow
  Color(0xFF008300), // green
];
const _categoricalDark = [
  Color(0xFF3987E5),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFF008300),
];

/// The number of distinct series a single chart may show; beyond this,
/// series fold away (we keep the most frequent) rather than cycling hues.
const maxChartSeries = 4;

List<Color> categoricalSeriesColors(Brightness brightness) =>
    brightness == Brightness.dark ? _categoricalDark : _categoricalLight;

/// Recessive horizontal-only grid.
FlGridData chartGrid(BuildContext context) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (value) => FlLine(
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    strokeWidth: 1,
  ),
);

TextStyle chartLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

/// Bottom axis titles for a day-based x axis: first, middle and last day
/// only, so labels never collide.
AxisTitles dayAxisTitles(BuildContext context, DateRange range) {
  final locale = Localizations.localeOf(context).toString();
  final format = DateFormat.Md(locale);
  final lastIndex = range.lengthInDays - 1;
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 28,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final index = value.round();
        final isEdgeOrMiddle =
            index == 0 || index == lastIndex || index == lastIndex ~/ 2;
        if (!isEdgeOrMiddle || index > lastIndex || index < 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            format.format(range.start.addDays(index).toDateTime()),
            style: chartLabelStyle(context),
          ),
        );
      },
    ),
  );
}

AxisTitles leftAxisTitles(BuildContext context, {double reservedSize = 34}) =>
    AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reservedSize,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          child: Text(meta.formattedValue, style: chartLabelStyle(context)),
        ),
      ),
    );

const noAxisTitles = AxisTitles();
