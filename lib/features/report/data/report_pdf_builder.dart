import 'dart:typed_data';

import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/meals/domain/meal_item_label.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/report/domain/report_data.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders [data] to a PDF document. Pure — no providers, no BuildContext —
/// so tests can drive it with a fixture and `lookupAppLocalizations`.
Future<pw.Document> buildReportDocument({
  required ReportData data,
  required AppLocalizations l10n,
  required String localeTag,
  required pw.ThemeData theme,
  required DateTime generatedAt,
}) async {
  final builder = _ReportBuilder(data, l10n, localeTag);
  final doc = pw.Document()
    ..addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        ),
        // The default (20) is far too low for 90-day daily logs.
        maxPages: 400,
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : builder.pageHeader(),
        footer: (context) => builder.pageFooter(context, generatedAt),
        build: (context) => builder.body(),
      ),
    );
  return doc;
}

Future<Uint8List> buildReportPdf({
  required ReportData data,
  required AppLocalizations l10n,
  required String localeTag,
  required pw.ThemeData theme,
  required DateTime generatedAt,
}) async {
  final doc = await buildReportDocument(
    data: data,
    l10n: l10n,
    localeTag: localeTag,
    theme: theme,
    generatedAt: generatedAt,
  );
  return doc.save();
}

const _muted = PdfColors.grey700;
const _barColor = PdfColors.blueGrey600;
const _barTrack = PdfColors.grey300;
const _barWidth = 250.0;

class _ReportBuilder {
  _ReportBuilder(this.data, this.l10n, String localeTag)
    : dateFormat = DateFormat.yMMMd(localeTag),
      dayFormat = DateFormat.yMMMEd(localeTag),
      timeFormat = DateFormat.Hm(localeTag);

  final ReportData data;
  final AppLocalizations l10n;
  final DateFormat dateFormat;
  final DateFormat dayFormat;
  final DateFormat timeFormat;

  String get _rangeLabel => l10n.reportRangeValue(
    dateFormat.format(data.range.start.toDateTime()),
    dateFormat.format(data.range.end.toDateTime()),
  );

  pw.Widget pageHeader() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _barTrack, width: 0.5)),
    ),
    child: pw.Text(
      '${l10n.appTitle} — $_rangeLabel',
      style: const pw.TextStyle(fontSize: 9, color: _muted),
    ),
  );

  pw.Widget pageFooter(pw.Context context, DateTime generatedAt) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              l10n.reportGeneratedOn(dateFormat.format(generatedAt.toLocal())),
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.Text(
              l10n.reportPage(context.pageNumber, context.pagesCount),
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      );

  List<pw.Widget> body() => [
    ..._titleBlock(),
    ..._section(
      l10n.sectionSymptomIntensity,
      annotation: l10n.sectionSymptomIntensitySubtitle,
      _symptomIntensity(),
    ),
    ..._section(l10n.sectionSymptomFrequency, _symptomFrequency()),
    ..._section(
      l10n.sectionBristol,
      annotation: data.bristolDistribution.isEmpty
          ? null
          : l10n.bristolNormalShare(_normalBristolShare()),
      _bristol(),
    ),
    ..._section(l10n.sectionWeight, _weight()),
    ..._section(l10n.sectionWater, _water()),
    ..._section(l10n.sectionSleep, _sleep()),
    ..._section(l10n.sectionActivity, _activity()),
    if (data.kcalByDay.isNotEmpty)
      ..._section(l10n.sectionNutrition, _nutrition()),
    ..._section(l10n.sectionAdherence, _adherence()),
    if (data.days case final days?) ..._dailyLog(days),
  ];

  List<pw.Widget> _titleBlock() => [
    pw.Text(
      l10n.appTitle,
      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 2),
    pw.Text(l10n.reportTitle, style: const pw.TextStyle(fontSize: 14)),
    pw.SizedBox(height: 6),
    pw.Text(
      '${l10n.reportPeriodLabel}: $_rangeLabel',
      style: const pw.TextStyle(fontSize: 11, color: _muted),
    ),
    pw.SizedBox(height: 12),
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _barTrack, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        l10n.reportDisclaimer,
        style: pw.TextStyle(
          fontSize: 9,
          color: _muted,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    ),
    pw.SizedBox(height: 8),
  ];

  /// Title (+ optional annotation) and content as flat children, so
  /// MultiPage can paginate between them.
  List<pw.Widget> _section(
    String title,
    List<pw.Widget> content, {
    String? annotation,
  }) => [
    pw.SizedBox(height: 12),
    pw.Text(
      title,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
    if (annotation != null)
      pw.Text(
        annotation,
        style: const pw.TextStyle(fontSize: 9, color: _muted),
      ),
    pw.SizedBox(height: 4),
    ...content,
  ];

  List<pw.Widget> _noData() => [
    pw.Text(
      l10n.reportNoData,
      style: const pw.TextStyle(fontSize: 10, color: _muted),
    ),
  ];

  String _symptomLabel(String typeId) =>
      switch (data.symptomTypesById[typeId]) {
        final type? => l10n.symptomTypeLabel(type),
        null => typeId,
      };

  List<pw.Widget> _symptomIntensity() {
    // Ordered by frequency, like the Stats screen.
    final rows = [
      for (final id in data.symptomFrequency.keys)
        if (data.symptomIntensity[id] case final values?)
          [
            _symptomLabel(id),
            _mean([for (final value in values) value.value]).toStringAsFixed(1),
          ],
    ];
    if (rows.isEmpty) return _noData();
    return [
      pw.TableHelper.fromTextArray(
        headers: [l10n.reportColSymptom, l10n.reportColAvgIntensity],
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.all(color: _barTrack, width: 0.5),
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
    ];
  }

  List<pw.Widget> _symptomFrequency() {
    if (data.symptomFrequency.isEmpty) return _noData();
    final maxCount = data.symptomFrequency.values.reduce(
      (a, b) => a > b ? a : b,
    );
    return [
      for (final entry in data.symptomFrequency.entries)
        _barRow(_symptomLabel(entry.key), entry.value, maxCount),
    ];
  }

  List<pw.Widget> _bristol() {
    if (data.bristolDistribution.isEmpty) return _noData();
    final maxCount = data.bristolDistribution.values.reduce(
      (a, b) => a > b ? a : b,
    );
    return [
      for (var type = 1; type <= 7; type++)
        _barRow(
          '${l10n.bristolTitle(type)} — ${l10n.bristolDescription(type)}',
          data.bristolDistribution[type] ?? 0,
          maxCount,
        ),
    ];
  }

  pw.Widget _barRow(String label, int count, int maxCount) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 190,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Container(
          width: _barWidth,
          height: 7,
          decoration: pw.BoxDecoration(
            color: _barTrack,
            borderRadius: pw.BorderRadius.circular(2),
          ),
          alignment: pw.Alignment.centerLeft,
          // A zero-width child still paints its rounded border as a sliver.
          child: count == 0 || maxCount == 0
              ? null
              : pw.Container(
                  width: _barWidth * count / maxCount,
                  height: 7,
                  decoration: pw.BoxDecoration(
                    color: _barColor,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                ),
        ),
        pw.SizedBox(width: 6),
        pw.SizedBox(
          width: 24,
          child: pw.Text(
            '$count',
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );

  List<pw.Widget> _weight() {
    if (data.weightDaily.isEmpty) return _noData();
    final values = [for (final value in data.weightDaily) value.value];
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return [
      _summaryLine(
        l10n.weightMinAvgMax(
          min.toStringAsFixed(1),
          _mean(values).toStringAsFixed(1),
          max.toStringAsFixed(1),
        ),
      ),
    ];
  }

  List<pw.Widget> _water() {
    if (data.waterDaily.isEmpty) return _noData();
    final avg = _mean([
      for (final value in data.waterDaily) value.value,
    ]).round();
    return [_summaryLine(l10n.reportWaterAvgPerDay(avg, data.waterGoalMl))];
  }

  List<pw.Widget> _sleep() {
    if (data.sleepDaily.isEmpty) return _noData();
    final avg = _mean([
      for (final value in data.sleepDaily) value.value,
    ]).round();
    return [_summaryLine(l10n.sleepAverage(avg ~/ 60, avg % 60))];
  }

  List<pw.Widget> _activity() {
    if (data.activityDaily.isEmpty) return _noData();
    final total = data.activityDaily
        .fold<double>(0, (sum, value) => sum + value.value)
        .round();
    return [
      _summaryLine(
        l10n.reportActivitySummary(data.activityDaily.length, total),
      ),
    ];
  }

  List<pw.Widget> _adherence() {
    final rows = [
      for (final (medication, summary) in data.adherence)
        if (summary.ratio case final ratio?)
          [
            switch (medication.dosage) {
              final dosage? => '${medication.name} — $dosage',
              null => medication.name,
            },
            l10n.medsProgress(summary.takenDoses, summary.expectedDoses),
            l10n.adherencePercent((ratio * 100).round()),
          ],
    ];
    if (rows.isEmpty) return _noData();
    return [
      pw.TableHelper.fromTextArray(
        headers: [
          l10n.reportColMedication,
          l10n.reportColDoses,
          l10n.reportColAdherence,
        ],
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.all(color: _barTrack, width: 0.5),
        cellAlignments: {2: pw.Alignment.centerRight},
      ),
    ];
  }

  /// Rendered only when there is at least one estimated total — the report
  /// stays free of an all-empty table for users who never enter nutrition.
  List<pw.Widget> _nutrition() {
    final days = data.kcalByDay.keys.toList()..sort();
    return [
      pw.TableHelper.fromTextArray(
        headers: [l10n.reportColDate, l10n.reportColKcal],
        data: [
          for (final day in days)
            [
              dateFormat.format(LocalDay(day).toDateTime()),
              l10n.nutritionKcalValue(data.kcalByDay[day]!.round()),
            ],
        ],
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.all(color: _barTrack, width: 0.5),
        cellAlignments: {1: pw.Alignment.centerRight},
      ),
    ];
  }

  pw.Widget _summaryLine(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 10));

  // -- Daily log ----------------------------------------------------------
  //
  // Every day is emitted as flat children (header, one row per entry, water
  // line): MultiPage cannot split a single oversized widget, so a day must
  // never be one block.

  List<pw.Widget> _dailyLog(List<DiaryDay> days) => [
    pw.SizedBox(height: 16),
    pw.Text(
      l10n.reportDailyLog,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    if (days.isEmpty) ...[pw.SizedBox(height: 4), ..._noData()],
    for (final day in days) ..._dayBlock(day),
  ];

  List<pw.Widget> _dayBlock(DiaryDay day) => [
    pw.Container(
      margin: const pw.EdgeInsets.only(top: 10, bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      width: double.infinity,
      color: PdfColors.grey200,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            dayFormat.format(day.day.toDateTime()),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          if (data.kcalByDay[day.day.value] case final kcal?)
            pw.Text(
              l10n.nutritionKcalValue(kcal.round()),
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
        ],
      ),
    ),
    if (day.sleep case final sleep?)
      _entryRow(
        null,
        l10n.quickAddSleep,
        _joinDetails([
          l10n.sleepHoursMinutes(
            sleep.durationMinutes ~/ 60,
            sleep.durationMinutes % 60,
          ),
          if (sleep.quality case final quality?)
            l10n.sleepQualityValue(quality),
        ]),
        notes: sleep.notes,
      ),
    for (final entry in _timedEntries(day)) entry,
    if (day.waterIntakes.isNotEmpty)
      _entryRow(
        null,
        l10n.waterCardTitle,
        l10n.waterProgress(day.totalWaterMl, data.waterGoalMl),
      ),
  ];

  /// All timed entries of the day, chronological — mirrors EntryTimeline.
  List<pw.Widget> _timedEntries(DiaryDay day) {
    final items = <(DateTime, pw.Widget)>[
      for (final meal in day.meals)
        (
          meal.occurredAt,
          _entryRow(
            meal.occurredAt,
            l10n.mealTypeLabel(meal.type),
            _joinDetails([
              // Grams when known ("Pasta 120 g"), the free-text portion
              // as fallback for historical rows without an amount.
              for (final item in meal.items)
                switch (item.portionDescription) {
                  final portion? when item.amountG == null =>
                    '${item.food.name} ($portion)',
                  _ => mealItemLabel(item),
                },
            ]),
            notes: meal.notes,
          ),
        ),
      for (final symptom in day.symptoms)
        (
          symptom.occurredAt,
          _entryRow(
            symptom.occurredAt,
            _symptomLabel(symptom.symptomTypeId),
            _joinDetails([
              l10n.intensityOutOf10(symptom.intensity),
              if (symptom.durationMinutes case final minutes?)
                l10n.minutesShort(minutes),
            ]),
            notes: symptom.notes,
          ),
        ),
      for (final movement in day.bowelMovements)
        (
          movement.occurredAt,
          _entryRow(
            movement.occurredAt,
            l10n.bristolTitle(movement.bristolType),
            _joinDetails([
              l10n.bristolDescription(movement.bristolType),
              if (movement.urgency) l10n.urgencyLabel,
              if (movement.pain case final pain?)
                '${l10n.painLabel} ${l10n.intensityOutOf10(pain)}',
              if (movement.blood) l10n.bloodLabel,
              if (movement.mucus) l10n.mucusLabel,
              if (movement.incompleteEvacuation) l10n.incompleteLabel,
            ]),
            notes: movement.notes,
          ),
        ),
      for (final weight in day.weightEntries)
        (
          weight.occurredAt,
          _entryRow(
            weight.occurredAt,
            l10n.weightKgValue(weight.weightKg.toStringAsFixed(1)),
            null,
            notes: weight.notes,
          ),
        ),
      for (final intake in day.medicationIntakes)
        (
          intake.occurredAt,
          _entryRow(
            intake.occurredAt,
            data.medicationsById[intake.medicationId]?.name ??
                l10n.quickAddMedication,
            intake.status == IntakeStatus.taken
                ? l10n.takenStatus
                : l10n.skippedStatus,
            notes: intake.notes,
          ),
        ),
      for (final activity in day.activities)
        (
          activity.occurredAt,
          _entryRow(
            activity.occurredAt,
            activity.name,
            _joinDetails([
              l10n.minutesShort(activity.durationMinutes),
              l10n.effortName(activity.effort),
            ]),
            notes: activity.notes,
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, widget) in items) widget];
  }

  pw.Widget _entryRow(
    DateTime? occurredAt,
    String label,
    String? detail, {
    String? notes,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 6, top: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 34,
          child: pw.Text(
            occurredAt != null ? timeFormat.format(occurredAt.toLocal()) : '',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 9),
                  children: [
                    pw.TextSpan(
                      text: label,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (detail != null && detail.isNotEmpty)
                      pw.TextSpan(text: ' — $detail'),
                  ],
                ),
              ),
              if (notes != null && notes.isNotEmpty)
                pw.Text(
                  notes,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    color: _muted,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  int _normalBristolShare() {
    final counts = data.bristolDistribution;
    final total = counts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return 0;
    final normal = (counts[3] ?? 0) + (counts[4] ?? 0);
    return (normal * 100 / total).round();
  }

  static String _joinDetails(List<String> parts) => parts.join(' · ');

  static double _mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}
