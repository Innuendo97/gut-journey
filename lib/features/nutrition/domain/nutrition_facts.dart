import 'package:meta/meta.dart';

/// `food_attributes` namespace of this feature: `(nutrition, <key>)` →
/// a user-entered estimate for one typical serving of the food.
const nutritionAttributeSource = 'nutrition';
const nutritionKcalKey = 'kcal_per_serving';
const nutritionServingDescKey = 'serving_description';
const nutritionProteinKey = 'protein_g';
const nutritionCarbsKey = 'carbs_g';
const nutritionFatKey = 'fat_g';
const nutritionFiberKey = 'fiber_g';

/// Every key this feature may store, in editor display order.
const nutritionAttributeKeys = [
  nutritionKcalKey,
  nutritionServingDescKey,
  nutritionProteinKey,
  nutritionCarbsKey,
  nutritionFatKey,
  nutritionFiberKey,
];

/// User-entered nutrition estimates for one typical serving of a food.
/// Every field is optional: an absent value simply means "not tracked".
@immutable
class NutritionFacts {
  const NutritionFacts({
    this.kcalPerServing,
    this.servingDescription,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  /// Parses stored attribute values; unparseable numbers become null so a
  /// corrupt row can never crash the app.
  factory NutritionFacts.fromAttributes(Map<String, String> attributes) {
    double? number(String key) {
      final raw = attributes[key];
      return raw == null ? null : double.tryParse(raw);
    }

    final servingDescription = attributes[nutritionServingDescKey]?.trim();
    return NutritionFacts(
      kcalPerServing: number(nutritionKcalKey),
      servingDescription: (servingDescription?.isEmpty ?? true)
          ? null
          : servingDescription,
      proteinG: number(nutritionProteinKey),
      carbsG: number(nutritionCarbsKey),
      fatG: number(nutritionFatKey),
      fiberG: number(nutritionFiberKey),
    );
  }

  final double? kcalPerServing;
  final String? servingDescription;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;

  bool get isEmpty =>
      kcalPerServing == null &&
      servingDescription == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      fiberG == null;

  /// Attribute values to persist; null fields are omitted (their stored
  /// rows get removed on save).
  Map<String, String> toAttributes() => {
    if (kcalPerServing != null) nutritionKcalKey: '$kcalPerServing',
    nutritionServingDescKey: ?servingDescription,
    if (proteinG != null) nutritionProteinKey: '$proteinG',
    if (carbsG != null) nutritionCarbsKey: '$carbsG',
    if (fatG != null) nutritionFatKey: '$fatG',
    if (fiberG != null) nutritionFiberKey: '$fiberG',
  };

  @override
  bool operator ==(Object other) =>
      other is NutritionFacts &&
      other.kcalPerServing == kcalPerServing &&
      other.servingDescription == servingDescription &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG;

  @override
  int get hashCode => Object.hash(
    kcalPerServing,
    servingDescription,
    proteinG,
    carbsG,
    fatG,
    fiberG,
  );

  @override
  String toString() => 'NutritionFacts(${toAttributes()})';
}
