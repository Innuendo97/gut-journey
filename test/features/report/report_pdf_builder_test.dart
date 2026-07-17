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

  ReportData fixture({List<DiaryDay>? days}) {
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
