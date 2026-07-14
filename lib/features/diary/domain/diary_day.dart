import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/domain/activity_entry.dart';
import 'package:gut_journey/features/bowel/domain/bowel_movement.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';
import 'package:gut_journey/features/sleep/domain/sleep_entry.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';
import 'package:gut_journey/features/water/domain/water_intake.dart';
import 'package:gut_journey/features/weight/domain/weight_entry.dart';

part 'diary_day.freezed.dart';

/// Everything logged on one diary day. There is no "day" table — this
/// aggregate is assembled in memory from the per-tracker streams.
@freezed
abstract class DiaryDay with _$DiaryDay {
  const factory DiaryDay({
    required LocalDay day,
    @Default(<MealEntry>[]) List<MealEntry> meals,
    @Default(<SymptomEntry>[]) List<SymptomEntry> symptoms,
    @Default(<BowelMovement>[]) List<BowelMovement> bowelMovements,
    @Default(<WeightEntry>[]) List<WeightEntry> weightEntries,
    @Default(<MedicationIntake>[]) List<MedicationIntake> medicationIntakes,
    @Default(<WaterIntake>[]) List<WaterIntake> waterIntakes,
    @Default(<ActivityEntry>[]) List<ActivityEntry> activities,
    SleepEntry? sleep,
  }) = _DiaryDay;

  const DiaryDay._();

  int get totalWaterMl =>
      waterIntakes.fold(0, (sum, intake) => sum + intake.amountMl);

  bool get isEmpty =>
      meals.isEmpty &&
      symptoms.isEmpty &&
      bowelMovements.isEmpty &&
      weightEntries.isEmpty &&
      medicationIntakes.isEmpty &&
      waterIntakes.isEmpty &&
      activities.isEmpty &&
      sleep == null;
}
