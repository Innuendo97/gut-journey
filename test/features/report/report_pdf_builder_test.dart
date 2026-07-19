import 'dart:convert' show latin1;
import 'dart:io' show zlib;

import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/domain/activity_entry.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/bowel/domain/bowel_movement.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';
import 'package:gut_journey/features/report/data/report_fonts.dart';
import 'package:gut_journey/features/report/data/report_pdf_builder.dart';
import 'package:gut_journey/features/report/domain/report_data.dart';
import 'package:gut_journey/features/sleep/domain/sleep_entry.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/features/water/domain/water_intake.dart';
import 'package:gut_journey/features/weight/domain/weight_entry.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

/// Recovers every string the document draws, in drawing order, words
/// joined by single spaces (each word is its own text operation, so the
/// original spacing is gone). Text is stored as glyph indices of the
/// embedded TTF fonts; this maps them back through each font's /ToUnicode
/// CMap.
Future<String> extractPdfText(pw.Document doc) async {
  final raw = latin1.decode(await doc.save());

  // Objects: number → dictionary text and inflated stream text.
  final dicts = <int, String>{};
  final streams = <int, String>{};
  final header = RegExp(r'(\d+) 0 obj');
  final streamKeyword = RegExp(r'>>\s*stream\r?\n');
  var pos = 0;
  for (;;) {
    Match? m;
    for (final candidate in header.allMatches(raw, pos)) {
      m = candidate;
      break;
    }
    if (m == null) break;
    final number = int.parse(m[1]!);
    final tail = raw.substring(m.end);
    final stream = streamKeyword.firstMatch(tail);
    final endObj = tail.indexOf('endobj');
    if (stream != null && (endObj == -1 || stream.start < endObj)) {
      final dict = tail.substring(0, stream.start + 2);
      dicts[number] = dict;
      // /Length is always a direct number in the pdf package, and binary
      // stream data may contain 'endobj' bytes — slice by length instead.
      final length = int.parse(RegExp(r'/Length (\d+)').firstMatch(dict)![1]!);
      final data = tail.substring(stream.end, stream.end + length);
      try {
        streams[number] = latin1.decode(zlib.decode(latin1.encode(data)));
      } on Object {
        streams[number] = data; // Not deflated.
      }
      pos = m.end + stream.end + length;
    } else {
      dicts[number] = endObj == -1 ? tail : tail.substring(0, endObj);
      pos = endObj == -1 ? raw.length : m.end + endObj;
    }
  }

  // Font resource name ('/F<objser>') → glyph index → rune.
  final cmaps = <String, Map<int, int>>{};
  for (final entry in dicts.entries) {
    final toUnicode = RegExp(r'/ToUnicode (\d+) 0 R').firstMatch(entry.value);
    if (toUnicode == null) continue;
    cmaps['F${entry.key}'] = {
      for (final pair in RegExp(
        '<([0-9A-Fa-f]{4})> <([0-9A-Fa-f]{4})>',
      ).allMatches(streams[int.parse(toUnicode[1]!)] ?? ''))
        int.parse(pair[1]!, radix: 16): int.parse(pair[2]!, radix: 16),
    };
  }

  // Content streams: track the selected font, decode every [<glyphs>]TJ.
  final words = <String>[];
  final token = RegExp(r'/(F\d+) [\d.]+ Tf|<([0-9A-Fa-f]+)>\]TJ');
  for (final stream in streams.values) {
    if (!stream.contains('BT')) continue;
    Map<int, int>? cmap;
    for (final m in token.allMatches(stream)) {
      if (m[1] != null) {
        cmap = cmaps[m[1]!];
      } else if (cmap != null) {
        final hex = m[2]!;
        words.add(
          String.fromCharCodes([
            for (var i = 0; i + 4 <= hex.length; i += 4)
              cmap[int.parse(hex.substring(i, i + 4), radix: 16)] ?? 0x3F,
          ]),
        );
      }
    }
  }
  return words.join(' ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late pw.ThemeData theme;

  final generatedAt = DateTime.utc(2026, 7, 14, 12);
  final range = DateRange(LocalDay('2026-04-16'), LocalDay('2026-07-14'));

  setUpAll(() async {
    // Nothing loads intl's non-English date symbols outside a widget tree.
    await initializeDateFormatting();
    theme = await loadReportTheme();
  });

  DiaryDay fullDay(LocalDay day) {
    final noon = day.toDateTime().add(const Duration(hours: 12));
    return DiaryDay(
      day: day,
      meals: [
        MealEntry(
          id: 'meal-${day.value}',
          type: MealType.lunch,
          occurredAt: noon,
          day: day,
          items: const [
            MealItem(
              food: FoodItem(id: 'food-1', name: 'Caffè žažolí'),
              portionDescription: '1 tazza',
            ),
            MealItem(
              food: FoodItem(id: 'food-2', name: 'Pasta'),
              amountG: 120,
            ),
          ],
          notes: 'Con «virgolette» tipografiche',
        ),
      ],
      symptoms: [
        SymptomEntry(
          id: 'symptom-${day.value}',
          symptomTypeId: 'custom-1',
          intensity: 6,
          occurredAt: noon.add(const Duration(hours: 2)),
          day: day,
          durationMinutes: 45,
        ),
      ],
      bowelMovements: [
        BowelMovement(
          id: 'bowel-${day.value}',
          bristolType: 4,
          occurredAt: noon.add(const Duration(hours: 3)),
          day: day,
          urgency: true,
          pain: 3,
        ),
      ],
      weightEntries: [
        WeightEntry(
          id: 'weight-${day.value}',
          weightKg: 70.4,
          occurredAt: noon.subtract(const Duration(hours: 4)),
          day: day,
        ),
      ],
      medicationIntakes: [
        MedicationIntake(
          id: 'intake-${day.value}',
          medicationId: 'med-1',
          status: IntakeStatus.taken,
          occurredAt: noon.subtract(const Duration(hours: 3)),
          day: day,
        ),
      ],
      waterIntakes: [
        WaterIntake(
          id: 'water-${day.value}',
          amountMl: 1500,
          occurredAt: noon,
          day: day,
        ),
      ],
      activities: [
        ActivityEntry(
          id: 'activity-${day.value}',
          name: 'Šport — jôga',
          durationMinutes: 30,
          effort: Effort.moderate,
          occurredAt: noon.add(const Duration(hours: 6)),
          day: day,
        ),
      ],
      sleep: SleepEntry(
        id: 'sleep-${day.value}',
        day: day,
        durationMinutes: 430,
        quality: 4,
      ),
    );
  }

  ReportData fixture({
    List<DiaryDay>? days,
    Map<String, double> kcalByDay = const {},
  }) {
    final medication = Medication(
      id: 'med-1',
      name: 'Ranitidină forte',
      scheduleType: ScheduleType.daily,
      startDay: LocalDay('2026-04-01'),
      scheduledTimes: const ['08:00'],
      dosage: '20 mg',
    );
    return ReportData(
      range: range,
      symptomIntensity: {
        'custom-1': [
          for (final day in range.days) DailyValue(day, 5),
        ],
      },
      symptomFrequency: const {'custom-1': 90, 'missing-type': 3},
      symptomTypesById: const {
        'custom-1': SymptomType(id: 'custom-1', customName: 'Gonfiore žołć'),
      },
      bristolDistribution: const {3: 20, 4: 40, 6: 5},
      weightDaily: [
        for (final day in range.days) DailyValue(day, 70.5),
      ],
      waterDaily: [
        for (final day in range.days) DailyValue(day, 1500),
      ],
      waterGoalMl: 2000,
      sleepDaily: [
        for (final day in range.days) DailyValue(day, 430),
      ],
      activityDaily: [
        for (final day in range.days) DailyValue(day, 25),
      ],
      adherence: [
        (medication, const AdherenceSummary(expectedDoses: 90, takenDoses: 81)),
      ],
      medicationsById: {'med-1': medication},
      kcalByDay: kcalByDay,
      days: days,
    );
  }

  test('renders a summary-only report in English and Italian', () async {
    for (final locale in const [Locale('en'), Locale('it')]) {
      final bytes = await buildReportPdf(
        data: fixture(),
        l10n: lookupAppLocalizations(locale),
        localeTag: locale.toString(),
        theme: theme,
        generatedAt: generatedAt,
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    }
  });

  test('paginates a 90-day daily log without hitting maxPages', () async {
    final withLog = await buildReportDocument(
      data: fixture(days: [for (final day in range.days) fullDay(day)]),
      l10n: lookupAppLocalizations(const Locale('it')),
      localeTag: 'it',
      theme: theme,
      generatedAt: generatedAt,
    );
    final summaryOnly = await buildReportDocument(
      data: fixture(),
      l10n: lookupAppLocalizations(const Locale('it')),
      localeTag: 'it',
      theme: theme,
      generatedAt: generatedAt,
    );

    final logPages = withLog.document.pdfPageList.pages.length;
    final summaryPages = summaryOnly.document.pdfPageList.pages.length;
    expect(logPages, greaterThan(1));
    expect(summaryPages, lessThan(logPages));
  });

  test('renders kcal totals, gram amounts and the nutrition section', () async {
    final day = LocalDay('2026-07-08');
    final doc = await buildReportDocument(
      data: fixture(
        days: [fullDay(day)],
        kcalByDay: {'2026-07-08': 640.4, '2026-07-09': 512},
      ),
      l10n: lookupAppLocalizations(const Locale('en')),
      localeTag: 'en',
      theme: theme,
      generatedAt: generatedAt,
    );
    final text = await extractPdfText(doc);

    // Day header carries the day's estimated total, rounded.
    expect(text, contains('640 kcal'));
    // Gram amounts on meal items, portion-description fallback preserved.
    expect(text, contains('Pasta 120 g'));
    expect(text, contains('Caffè žažolí (1 tazza)'));
    // Summary section with one row per day.
    expect(text, contains('Estimated energy'));
    expect(text, contains('512 kcal'));
  });

  test('omits the nutrition section without kcal data', () async {
    final doc = await buildReportDocument(
      data: fixture(),
      l10n: lookupAppLocalizations(const Locale('en')),
      localeTag: 'en',
      theme: theme,
      generatedAt: generatedAt,
    );
    final text = await extractPdfText(doc);
    expect(text, isNot(contains('Estimated energy')));
    expect(text, isNot(contains('kcal')));
  });

  test('renders when every section is empty', () async {
    final bytes = await buildReportPdf(
      data: ReportData(
        range: range,
        symptomIntensity: const {},
        symptomFrequency: const {},
        symptomTypesById: const {},
        bristolDistribution: const {},
        weightDaily: const [],
        waterDaily: const [],
        waterGoalMl: 2000,
        sleepDaily: const [],
        activityDaily: const [],
        adherence: const [],
        medicationsById: const {},
        days: const [],
      ),
      l10n: lookupAppLocalizations(const Locale('en')),
      localeTag: 'en',
      theme: theme,
      generatedAt: generatedAt,
    );
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
  });
}
