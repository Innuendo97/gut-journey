import 'package:freezed_annotation/freezed_annotation.dart';

part 'correlation_models.freezed.dart';
part 'correlation_models.g.dart';

/// How strongly an observed food↔symptom pattern stands out from its
/// baseline. Buckets of [FoodSymptomAssociation.adjustedLift]; serialized by
/// name — never rename values.
enum CorrelationStrength { weak, moderate, strong }

/// An observed association between a food and a symptom type: how often the
/// symptom followed meals containing the food within a time window, against
/// the baseline of meals without it. A pattern in the diary data — never a
/// causal claim; wording around it must stay observational.
@freezed
abstract class FoodSymptomAssociation with _$FoodSymptomAssociation {
  const factory FoodSymptomAssociation({
    required String foodItemId,
    required String foodName,
    required String symptomTypeId,
    required int exposedMeals,
    required int exposedWithSymptom,
    required int baselineMeals,
    required int baselineWithSymptom,
    required double exposedRate,
    required double baselineRate,

    /// `exposedRate / baselineRate`, or null when the symptom never followed
    /// a baseline meal — an infinite ratio is never computed or shown.
    required double? lift,

    /// Haldane–Anscombe-corrected lift (+0.5 to each count): always finite
    /// and deliberately shrunk on small samples. Ranking and
    /// [CorrelationStrength] bucketing use this, not [lift].
    required double adjustedLift,
    required CorrelationStrength strength,
  }) = _FoodSymptomAssociation;

  factory FoodSymptomAssociation.fromJson(Map<String, dynamic> json) =>
      _$FoodSymptomAssociationFromJson(json);
}

/// The outcome of one correlation analysis run over a period.
@freezed
abstract class CorrelationsResult with _$CorrelationsResult {
  const factory CorrelationsResult({
    required Duration window,

    /// Meals considered: those with at least one food item (a meal with no
    /// items has unknown composition and can't sit on either side of the
    /// comparison).
    required int analyzedMeals,

    /// All symptom events supplied to the engine, eligible or not.
    required int analyzedSymptomEvents,

    /// Ranked strongest-first and already filtered by the thresholds.
    required List<FoodSymptomAssociation> associations,
  }) = _CorrelationsResult;

  factory CorrelationsResult.fromJson(Map<String, dynamic> json) =>
      _$CorrelationsResultFromJson(json);
}

/// Minimum-data gates below which a pair is noise, not a pattern. Enforced
/// inside the engine so every consumer sees the same filtered result.
class CorrelationThresholds {
  const CorrelationThresholds({
    this.minExposedMeals = 3,
    this.minBaselineMeals = 3,
    this.minExposedWithSymptom = 2,
    this.minSymptomEvents = 3,
    this.minAdjustedLift = 1.2,
  });

  /// Meals containing the food.
  final int minExposedMeals;

  /// Meals without the food — a food present in nearly every meal has no
  /// baseline to compare against.
  final int minBaselineMeals;

  /// Exposed meals followed by the symptom; a single co-occurrence is noise.
  final int minExposedWithSymptom;

  /// Total events a symptom type needs before it is analyzed at all.
  final int minSymptomEvents;

  /// Floor on [FoodSymptomAssociation.adjustedLift] for reporting.
  final double minAdjustedLift;
}
