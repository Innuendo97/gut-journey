import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';
import 'package:rxdart/rxdart.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(
    meals: ref.watch(mealRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
    bowel: ref.watch(bowelRepositoryProvider),
    weight: ref.watch(weightRepositoryProvider),
    medications: ref.watch(medicationRepositoryProvider),
    water: ref.watch(waterRepositoryProvider),
    sleep: ref.watch(sleepRepositoryProvider),
    activity: ref.watch(activityRepositoryProvider),
  ),
);

/// Assembles the [DiaryDay] aggregate from the per-tracker streams. This is
/// the single read path Today, History and future exports share.
class DiaryRepository {
  DiaryRepository({
    required MealRepository meals,
    required SymptomRepository symptoms,
    required BowelRepository bowel,
    required WeightRepository weight,
    required MedicationRepository medications,
    required WaterRepository water,
    required SleepRepository sleep,
    required ActivityRepository activity,
  }) : _meals = meals,
       _symptoms = symptoms,
       _bowel = bowel,
       _weight = weight,
       _medications = medications,
       _water = water,
       _sleep = sleep,
       _activity = activity;

  final MealRepository _meals;
  final SymptomRepository _symptoms;
  final BowelRepository _bowel;
  final WeightRepository _weight;
  final MedicationRepository _medications;
  final WaterRepository _water;
  final SleepRepository _sleep;
  final ActivityRepository _activity;

  Stream<DiaryDay> watchDay(LocalDay day) {
    return CombineLatestStream.combine8(
      _meals.watchByDay(day),
      _symptoms.watchByDay(day),
      _bowel.watchByDay(day),
      _weight.watchByDay(day),
      _medications.watchIntakesByDay(day),
      _water.watchByDay(day),
      _sleep.watchByDay(day),
      _activity.watchByDay(day),
      (meals, symptoms, bowel, weight, intakes, water, sleep, activities) =>
          DiaryDay(
            day: day,
            meals: meals,
            symptoms: symptoms,
            bowelMovements: bowel,
            weightEntries: weight,
            medicationIntakes: intakes,
            waterIntakes: water,
            sleep: sleep,
            activities: activities,
          ),
    );
  }
}
