import 'package:meta/meta.dart';

/// `food_attributes` namespace of this feature: `(nutrition, <key>)` →
/// a user-entered nutrition estimate for the food.
const nutritionAttributeSource = 'nutrition';

// Canonical base: values per 100 g (per 100 ml for liquids).
const nutritionKcal100Key = 'kcal_per_100g';
const nutritionProtein100Key = 'protein_per_100g';
const nutritionCarbs100Key = 'carbs_per_100g';
const nutritionFat100Key = 'fat_per_100g';
const nutritionFiber100Key = 'fiber_per_100g';

/// Typical portion weight in grams — only a prefill for the amount field,
/// never part of a total.
const nutritionServingGKey = 'serving_g';

const nutritionServingDescKey = 'serving_description';

// Legacy per-serving estimates (pre-v0.5). Still read so historical rows
// keep their totals; new writes use the per-100g base.
const nutritionKcalKey = 'kcal_per_serving';
const nutritionProteinKey = 'protein_g';
const nutritionCarbsKey = 'carbs_g';
const nutritionFatKey = 'fat_g';
const nutritionFiberKey = 'fiber_g';

/// Every key this feature may store, in editor display order.
const nutritionAttributeKeys = [
  nutritionKcal100Key,
  nutritionProtein100Key,
  nutritionCarbs100Key,
  nutritionFat100Key,
  nutritionFiber100Key,
  nutritionServingGKey,
  nutritionServingDescKey,
  nutritionKcalKey,
  nutritionProteinKey,
  nutritionCarbsKey,
  nutritionFatKey,
  nutritionFiberKey,
];

/// One set of nutrient values. Whether they mean "per 100 g" or "per
/// serving" is decided by the [NutritionFacts] field holding them.
@immutable
class Nutrients {
  const Nutrients({
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
  });

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;

  bool get isEmpty =>
      kcal == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      fiberG == null;

  /// This set scaled by [factor]; absent values stay absent.
  Nutrients scale(double factor) => Nutrients(
    kcal: kcal == null ? null : kcal! * factor,
    proteinG: proteinG == null ? null : proteinG! * factor,
    carbsG: carbsG == null ? null : carbsG! * factor,
    fatG: fatG == null ? null : fatG! * factor,
    fiberG: fiberG == null ? null : fiberG! * factor,
  );

  /// Field-wise sum where absent values count as absent, not zero — a
  /// partial estimate stays visibly partial.
  Nutrients operator +(Nutrients other) {
    double? sum(double? a, double? b) =>
        a == null ? b : (b == null ? a : a + b);
    return Nutrients(
      kcal: sum(kcal, other.kcal),
      proteinG: sum(proteinG, other.proteinG),
      carbsG: sum(carbsG, other.carbsG),
      fatG: sum(fatG, other.fatG),
      fiberG: sum(fiberG, other.fiberG),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Nutrients &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG;

  @override
  int get hashCode => Object.hash(kcal, proteinG, carbsG, fatG, fiberG);

  @override
  String toString() =>
      'Nutrients(kcal: $kcal, P: $proteinG, C: $carbsG, F: $fatG, '
      'fiber: $fiberG)';
}

/// Nutrition estimates of one food. The canonical base is [per100]; foods
/// last edited before v0.5 only carry [legacyPerServing], which historical
/// meal rows keep using forever. Every field is optional: an absent value
/// simply means "not tracked".
@immutable
class NutritionFacts {
  const NutritionFacts({
    this.per100,
    this.servingG,
    this.legacyPerServing,
    this.servingDescription,
  });

  /// Parses stored attribute values; unparseable numbers become null so a
  /// corrupt row can never crash the app.
  factory NutritionFacts.fromAttributes(Map<String, String> attributes) {
    double? number(String key) {
      final raw = attributes[key];
      return raw == null ? null : double.tryParse(raw);
    }

    Nutrients? group(
      String kcal,
      String protein,
      String carbs,
      String fat,
      String fiber,
    ) {
      final nutrients = Nutrients(
        kcal: number(kcal),
        proteinG: number(protein),
        carbsG: number(carbs),
        fatG: number(fat),
        fiberG: number(fiber),
      );
      return nutrients.isEmpty ? null : nutrients;
    }

    final servingDescription = attributes[nutritionServingDescKey]?.trim();
    return NutritionFacts(
      per100: group(
        nutritionKcal100Key,
        nutritionProtein100Key,
        nutritionCarbs100Key,
        nutritionFat100Key,
        nutritionFiber100Key,
      ),
      servingG: number(nutritionServingGKey),
      legacyPerServing: group(
        nutritionKcalKey,
        nutritionProteinKey,
        nutritionCarbsKey,
        nutritionFatKey,
        nutritionFiberKey,
      ),
      servingDescription: (servingDescription?.isEmpty ?? true)
          ? null
          : servingDescription,
    );
  }

  /// Values per 100 g (per 100 ml for liquids) — the canonical base.
  final Nutrients? per100;

  /// Typical portion weight in grams, used only to prefill amounts.
  final double? servingG;

  /// Pre-v0.5 values for one typical serving.
  final Nutrients? legacyPerServing;

  final String? servingDescription;

  bool get isEmpty =>
      per100 == null &&
      servingG == null &&
      legacyPerServing == null &&
      servingDescription == null;

  /// Whether any formula can produce kcal for this food.
  bool get hasKcalBasis =>
      per100?.kcal != null || legacyPerServing?.kcal != null;

  /// The one engine behind every total: rows with an explicit [amountG]
  /// scale the per-100g base ("120 g of pasta"); historical rows (null
  /// amount) keep the legacy per-serving × servings formula forever. When
  /// the needed base is missing the result is null — never an error, and
  /// never a mix of the two formulas.
  Nutrients? nutrientsFor({double? amountG, double? quantity}) {
    if (amountG != null) return per100?.scale(amountG / 100);
    return legacyPerServing?.scale(quantity ?? 1);
  }

  double? kcalFor({double? amountG, double? quantity}) =>
      nutrientsFor(amountG: amountG, quantity: quantity)?.kcal;

  /// Attribute values to persist; null fields are omitted (their stored
  /// rows get removed on save).
  Map<String, String> toAttributes() => {
    if (per100?.kcal != null) nutritionKcal100Key: '${per100!.kcal}',
    if (per100?.proteinG != null) nutritionProtein100Key: '${per100!.proteinG}',
    if (per100?.carbsG != null) nutritionCarbs100Key: '${per100!.carbsG}',
    if (per100?.fatG != null) nutritionFat100Key: '${per100!.fatG}',
    if (per100?.fiberG != null) nutritionFiber100Key: '${per100!.fiberG}',
    if (servingG != null) nutritionServingGKey: '$servingG',
    nutritionServingDescKey: ?servingDescription,
    if (legacyPerServing?.kcal != null)
      nutritionKcalKey: '${legacyPerServing!.kcal}',
    if (legacyPerServing?.proteinG != null)
      nutritionProteinKey: '${legacyPerServing!.proteinG}',
    if (legacyPerServing?.carbsG != null)
      nutritionCarbsKey: '${legacyPerServing!.carbsG}',
    if (legacyPerServing?.fatG != null)
      nutritionFatKey: '${legacyPerServing!.fatG}',
    if (legacyPerServing?.fiberG != null)
      nutritionFiberKey: '${legacyPerServing!.fiberG}',
  };

  @override
  bool operator ==(Object other) =>
      other is NutritionFacts &&
      other.per100 == per100 &&
      other.servingG == servingG &&
      other.legacyPerServing == legacyPerServing &&
      other.servingDescription == servingDescription;

  @override
  int get hashCode =>
      Object.hash(per100, servingG, legacyPerServing, servingDescription);

  @override
  String toString() => 'NutritionFacts(${toAttributes()})';
}
