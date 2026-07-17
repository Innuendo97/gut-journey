import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:meta/meta.dart';

/// Localized display labels for the registry categories.
const registryCategoryLabels = <String, ({String it, String en})>{
  'cereali-pasta': (it: 'Cereali e pasta', en: 'Grains & pasta'),
  'pane-forno': (it: 'Pane e forno', en: 'Bread & bakery'),
  'legumi': (it: 'Legumi', en: 'Legumes'),
  'verdure': (it: 'Verdure', en: 'Vegetables'),
  'frutta': (it: 'Frutta', en: 'Fruit'),
  'frutta-secca-semi': (it: 'Frutta secca e semi', en: 'Nuts & seeds'),
  'pesce': (it: 'Pesce', en: 'Fish & seafood'),
  'carne': (it: 'Carne', en: 'Meat'),
  'salumi': (it: 'Salumi', en: 'Cured meats'),
  'latticini': (it: 'Latticini', en: 'Dairy'),
  'uova-grassi-condimenti': (
    it: 'Uova, grassi e condimenti',
    en: 'Eggs, fats & condiments',
  ),
  'dolci': (it: 'Dolci', en: 'Sweets'),
  'bevande': (it: 'Bevande', en: 'Drinks'),
  'piatti-mediterranei': (
    it: 'Piatti mediterranei',
    en: 'Mediterranean dishes',
  ),
  'sud-italia': (it: 'Sud Italia', en: 'Southern Italy'),
  'internazionale': (it: 'Internazionale', en: 'International'),
  'snack': (it: 'Snack', en: 'Snacks'),
  'altro': (it: 'Altro', en: 'Other'),
};

/// One food of the bundled registry: average per-100g values from standard
/// nutrition tables plus a typical Italian serving. Values are indicative
/// averages — the app's usual "estimates, not advice" framing applies.
@immutable
class RegistryFood {
  const RegistryFood({
    required this.id,
    required this.nameIt,
    required this.nameEn,
    required this.category,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.fiber100,
    required this.servingG,
    required this.servingIt,
    required this.servingEn,
    this.alcohol100,
  });

  factory RegistryFood.fromJson(Map<String, dynamic> json) {
    final per100 = json['per100g'] as Map<String, dynamic>;
    final serving = json['serving'] as Map<String, dynamic>;
    return RegistryFood(
      id: json['id'] as String,
      nameIt: json['it'] as String,
      nameEn: json['en'] as String,
      category: json['cat'] as String,
      kcal100: (per100['kcal'] as num).toDouble(),
      protein100: (per100['protein'] as num).toDouble(),
      carbs100: (per100['carbs'] as num).toDouble(),
      fat100: (per100['fat'] as num).toDouble(),
      fiber100: (per100['fiber'] as num).toDouble(),
      alcohol100: (per100['alcohol'] as num?)?.toDouble(),
      servingG: (serving['g'] as num).toDouble(),
      servingIt: serving['it'] as String,
      servingEn: serving['en'] as String,
    );
  }

  final String id;
  final String nameIt;
  final String nameEn;

  /// Registry category slug (see [registryCategoryLabels]).
  final String category;

  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final double? alcohol100;

  /// Typical serving in grams (ml for liquids).
  final double servingG;
  final String servingIt;
  final String servingEn;

  bool _isItalian(String languageCode) => languageCode == 'it';

  String name(String languageCode) =>
      _isItalian(languageCode) ? nameIt : nameEn;

  String servingDescription(String languageCode) =>
      _isItalian(languageCode) ? servingIt : servingEn;

  String categoryLabel(String languageCode) {
    final labels = registryCategoryLabels[category];
    if (labels == null) return category;
    return _isItalian(languageCode) ? labels.it : labels.en;
  }

  /// Estimated kcal for one typical serving.
  double get kcalPerServing => kcal100 * servingG / 100;

  /// Per-serving facts in the app's model, rounded to sensible precision
  /// (whole kcal, one decimal for macros).
  NutritionFacts toFacts(String languageCode) {
    double perServing(double per100) =>
        ((per100 * servingG / 100) * 10).roundToDouble() / 10;
    return NutritionFacts(
      kcalPerServing: kcalPerServing.roundToDouble(),
      servingDescription: servingDescription(languageCode),
      proteinG: perServing(protein100),
      carbsG: perServing(carbs100),
      fatG: perServing(fat100),
      fiberG: perServing(fiber100),
    );
  }
}
