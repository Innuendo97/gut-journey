import 'package:gut_journey/features/correlations/domain/correlation_models.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';

/// Derives observed food↔symptom associations from diary data.
///
/// Pure and deterministic: meals and symptom events in, ranked associations
/// out. Callers fetch symptoms slightly past the meal period so meals near
/// its end aren't truncation-biased.
class CorrelationEngine {
  const CorrelationEngine({this.thresholds = const CorrelationThresholds()});

  final CorrelationThresholds thresholds;

  CorrelationsResult compute({
    required List<MealEntry> meals,
    required List<SymptomEntry> symptoms,
    required Duration window,
  }) {
    final analyzed = [
      for (final meal in meals)
        if (meal.items.isNotEmpty) meal,
    ];

    final eventsByType = <String, List<DateTime>>{};
    for (final event in symptoms) {
      (eventsByType[event.symptomTypeId] ??= []).add(event.occurredAt);
    }
    eventsByType.removeWhere(
      (_, events) => events.length < thresholds.minSymptomEvents,
    );

    // occurredByType[typeId][i]: meal i was followed by the symptom within
    // (mealAt, mealAt + window]. An event logged at exactly the meal moment
    // is ambiguous and excluded; the end boundary is included. Several
    // events in one window count once; close-together meals may each claim
    // the same event — accepted and disclosed in the method explanation.
    final occurredByType = <String, List<bool>>{
      for (final MapEntry(key: typeId, value: events) in eventsByType.entries)
        typeId: [
          for (final meal in analyzed)
            events.any(
              (at) =>
                  at.isAfter(meal.occurredAt) &&
                  !at.isAfter(meal.occurredAt.add(window)),
            ),
        ],
    };

    final foodNames = <String, String>{};
    final mealFoodIds = <Set<String>>[];
    for (final meal in analyzed) {
      final ids = <String>{};
      for (final item in meal.items) {
        ids.add(item.food.id);
        foodNames[item.food.id] = item.food.name;
      }
      mealFoodIds.add(ids);
    }

    final associations = <FoodSymptomAssociation>[];
    for (final foodId in foodNames.keys) {
      final exposed = <int>[];
      final baseline = <int>[];
      for (var i = 0; i < analyzed.length; i++) {
        (mealFoodIds[i].contains(foodId) ? exposed : baseline).add(i);
      }
      if (exposed.length < thresholds.minExposedMeals) continue;
      if (baseline.length < thresholds.minBaselineMeals) continue;

      for (final MapEntry(key: typeId, value: occurred)
          in occurredByType.entries) {
        final exposedWith = exposed.where((i) => occurred[i]).length;
        final baselineWith = baseline.where((i) => occurred[i]).length;
        if (exposedWith < thresholds.minExposedWithSymptom) continue;

        final exposedRate = exposedWith / exposed.length;
        final baselineRate = baselineWith / baseline.length;
        if (exposedRate <= baselineRate) continue;

        final adjustedLift =
            ((exposedWith + 0.5) / (exposed.length + 1)) /
            ((baselineWith + 0.5) / (baseline.length + 1));
        if (adjustedLift < thresholds.minAdjustedLift) continue;

        associations.add(
          FoodSymptomAssociation(
            foodItemId: foodId,
            foodName: foodNames[foodId]!,
            symptomTypeId: typeId,
            exposedMeals: exposed.length,
            exposedWithSymptom: exposedWith,
            baselineMeals: baseline.length,
            baselineWithSymptom: baselineWith,
            exposedRate: exposedRate,
            baselineRate: baselineRate,
            lift: baselineWith == 0 ? null : exposedRate / baselineRate,
            adjustedLift: adjustedLift,
            strength: _bucket(adjustedLift),
          ),
        );
      }
    }

    associations.sort(
      (a, b) => switch (b.strength.index.compareTo(a.strength.index)) {
        0 => switch (b.adjustedLift.compareTo(a.adjustedLift)) {
          0 => switch (b.exposedMeals.compareTo(a.exposedMeals)) {
            0 => a.foodName.compareTo(b.foodName),
            final byMeals => byMeals,
          },
          final byLift => byLift,
        },
        final byStrength => byStrength,
      },
    );

    return CorrelationsResult(
      window: window,
      analyzedMeals: analyzed.length,
      analyzedSymptomEvents: symptoms.length,
      associations: associations,
    );
  }

  CorrelationStrength _bucket(double adjustedLift) {
    if (adjustedLift >= 2.5) return CorrelationStrength.strong;
    if (adjustedLift >= 1.5) return CorrelationStrength.moderate;
    return CorrelationStrength.weak;
  }
}
