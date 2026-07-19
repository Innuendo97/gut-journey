import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/report/domain/report_data.dart';
import 'package:gut_journey/features/stats/data/stats_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';

final reportDataRepositoryProvider = Provider<ReportDataRepository>(
  (ref) => ReportDataRepository(
    stats: ref.watch(statsRepositoryProvider),
    diary: ref.watch(diaryRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
    medications: ref.watch(medicationRepositoryProvider),
    nutrition: ref.watch(nutritionRepositoryProvider),
  ),
);

/// One-shot collector behind the PDF report: first values of the same
/// streams Stats and the diary watch.
class ReportDataRepository {
  ReportDataRepository({
    required StatsRepository stats,
    required DiaryRepository diary,
    required SymptomRepository symptoms,
    required MedicationRepository medications,
    required NutritionRepository nutrition,
  }) : _stats = stats,
       _diary = diary,
       _symptoms = symptoms,
       _medications = medications,
       _nutrition = nutrition;

  final StatsRepository _stats;
  final DiaryRepository _diary;
  final SymptomRepository _symptoms;
  final MedicationRepository _medications;
  final NutritionRepository _nutrition;

  Future<ReportData> collect({
    required DateRange range,
    required bool includeDailyLog,
    required int waterGoalMl,
  }) async {
    final (
      symptomIntensity,
      symptomFrequency,
      bristolDistribution,
      weightDaily,
      waterDaily,
      sleepDaily,
      activityDaily,
      adherence,
      kcalDaily,
    ) = await (
      _stats.watchSymptomIntensity(range).first,
      _stats.watchSymptomFrequency(range).first,
      _stats.watchBristolDistribution(range).first,
      _stats.watchWeightDaily(range).first,
      _stats.watchWaterDaily(range).first,
      _stats.watchSleepDaily(range).first,
      _stats.watchActivityDaily(range).first,
      _stats.watchAdherence(range).first,
      _nutrition.watchKcalDaily(range).first,
    ).wait;

    final symptomTypes = await _symptoms
        .watchTypes(includeArchived: true)
        .first;
    final medications = await _medications.watchAll().first;

    List<DiaryDay>? days;
    if (includeDailyLog) {
      final allDays = await Future.wait([
        for (final day in range.days) _diary.watchDay(day).first,
      ]);
      days = [
        for (final day in allDays)
          if (!day.isEmpty) day,
      ];
    }

    return ReportData(
      range: range,
      symptomIntensity: symptomIntensity,
      symptomFrequency: symptomFrequency,
      symptomTypesById: {for (final type in symptomTypes) type.id: type},
      bristolDistribution: bristolDistribution,
      weightDaily: weightDaily,
      waterDaily: waterDaily,
      waterGoalMl: waterGoalMl,
      sleepDaily: sleepDaily,
      activityDaily: activityDaily,
      adherence: adherence,
      medicationsById: {
        for (final medication in medications) medication.id: medication,
      },
      kcalByDay: {for (final value in kcalDaily) value.day.value: value.value},
      days: days,
    );
  }
}
