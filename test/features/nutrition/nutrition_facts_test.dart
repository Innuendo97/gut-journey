import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';

void main() {
  const per100Only = NutritionFacts(
    per100: Nutrients(kcal: 350, proteinG: 12, carbsG: 70, fatG: 1.5),
  );
  const legacyOnly = NutritionFacts(
    legacyPerServing: Nutrients(kcal: 280, proteinG: 25),
  );
  const both = NutritionFacts(
    per100: Nutrients(kcal: 130),
    legacyPerServing: Nutrients(kcal: 220),
  );

  group('nutrientsFor', () {
    test('an explicit amount scales the per-100g base', () {
      final nutrients = per100Only.nutrientsFor(amountG: 120);
      expect(nutrients?.kcal, 420);
      expect(nutrients?.proteinG, closeTo(14.4, 1e-9));
      expect(nutrients?.fiberG, isNull); // absent values stay absent
    });

    test('a historical row uses legacy × servings, null quantity as one', () {
      expect(legacyOnly.nutrientsFor(quantity: 2)?.kcal, 560);
      expect(legacyOnly.nutrientsFor()?.kcal, 280);
    });

    test('per-100g wins for amount rows, legacy wins for historical '
        'rows', () {
      expect(both.kcalFor(amountG: 200), 260); // 130 × 2
      expect(both.kcalFor(quantity: 2), 440); // 220 × 2
    });

    test('a missing base yields null, never a cross-formula guess', () {
      // Grams of a legacy-only food: servings ≠ grams.
      expect(legacyOnly.nutrientsFor(amountG: 80), isNull);
      // Historical row of a per-100g-only food: no serving size known.
      expect(per100Only.nutrientsFor(quantity: 2), isNull);
      expect(const NutritionFacts().nutrientsFor(amountG: 100), isNull);
    });
  });

  test('hasKcalBasis needs kcal in either base', () {
    expect(per100Only.hasKcalBasis, isTrue);
    expect(legacyOnly.hasKcalBasis, isTrue);
    expect(const NutritionFacts().hasKcalBasis, isFalse);
    expect(
      const NutritionFacts(per100: Nutrients(proteinG: 10)).hasKcalBasis,
      isFalse,
    );
  });

  test('attributes round-trip both bases and the serving weight', () {
    const facts = NutritionFacts(
      per100: Nutrients(kcal: 350, fiberG: 3),
      servingG: 80,
      legacyPerServing: Nutrients(kcal: 282),
      servingDescription: 'una porzione (80 g)',
    );

    final attributes = facts.toAttributes();
    expect(attributes[nutritionKcal100Key], '350.0');
    expect(attributes[nutritionServingGKey], '80.0');
    expect(attributes[nutritionKcalKey], '282.0');
    expect(NutritionFacts.fromAttributes(attributes), facts);
  });
}
