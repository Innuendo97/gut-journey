import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/correlations/domain/correlation_engine.dart';
import 'package:gut_journey/features/correlations/domain/correlation_models.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:rxdart/rxdart.dart';

final correlationsRepositoryProvider = Provider<CorrelationsRepository>(
  (ref) => CorrelationsRepository(
    meals: ref.watch(mealRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
  ),
);

/// Live observed food↔symptom associations over a period: recomputed by the
/// pure [CorrelationEngine] whenever meals or symptoms change.
class CorrelationsRepository {
  CorrelationsRepository({
    required MealRepository meals,
    required SymptomRepository symptoms,
    this.engine = const CorrelationEngine(),
  }) : _meals = meals,
       _symptoms = symptoms;

  final MealRepository _meals;
  final SymptomRepository _symptoms;
  final CorrelationEngine engine;

  Stream<CorrelationsResult> watchAssociations({
    required DateRange range,
    required Duration window,
  }) {
    // Symptoms are fetched one day past the period so meals near its end
    // keep their full window (4/8/24h never spans more than a day).
    final symptomRange = DateRange(range.start, range.end.addDays(1));
    return CombineLatestStream.combine2(
      _meals.watchByRange(range),
      _symptoms.watchByRange(symptomRange),
      (meals, symptoms) =>
          engine.compute(meals: meals, symptoms: symptoms, window: window),
    );
  }
}
