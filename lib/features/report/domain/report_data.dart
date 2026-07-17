import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:meta/meta.dart';

/// Everything the PDF report renders, collected in one shot so the document
/// is built from a single consistent snapshot.
@immutable
class ReportData {
  const ReportData({
    required this.range,
    required this.symptomIntensity,
    required this.symptomFrequency,
    required this.symptomTypesById,
    required this.bristolDistribution,
    required this.weightDaily,
    required this.waterDaily,
    required this.waterGoalMl,
    required this.sleepDaily,
    required this.activityDaily,
    required this.adherence,
    required this.medicationsById,
    this.days,
  });

  final DateRange range;
  final Map<String, List<DailyValue>> symptomIntensity;

  /// Ordered most frequent first, like the Stats screen.
  final Map<String, int> symptomFrequency;
  final Map<String, SymptomType> symptomTypesById;
  final Map<int, int> bristolDistribution;
  final List<DailyValue> weightDaily;
  final List<DailyValue> waterDaily;
  final int waterGoalMl;
  final List<DailyValue> sleepDaily;
  final List<DailyValue> activityDaily;
  final List<(Medication, AdherenceSummary)> adherence;

  /// Includes inactive medications so old intakes in the daily log still
  /// resolve to a name.
  final Map<String, Medication> medicationsById;

  /// Non-empty days in chronological order; null when the daily log was not
  /// requested.
  final List<DiaryDay>? days;
}
