import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Localized display names for domain enums and preset keys. Kept together
/// so the "database stores keys, UI localizes them" rule has one home.
extension DomainLabels on AppLocalizations {
  String mealTypeLabel(MealType type) => switch (type) {
    MealType.breakfast => mealTypeBreakfast,
    MealType.lunch => mealTypeLunch,
    MealType.dinner => mealTypeDinner,
    MealType.snack => mealTypeSnack,
    MealType.drink => mealTypeDrink,
  };

  // Named effortName because the ARB already generates an effortLabel getter.
  String effortName(Effort effort) => switch (effort) {
    Effort.light => effortLight,
    Effort.moderate => effortModerate,
    Effort.vigorous => effortVigorous,
  };

  String bristolDescription(int type) => switch (type) {
    1 => bristol1,
    2 => bristol2,
    3 => bristol3,
    4 => bristol4,
    5 => bristol5,
    6 => bristol6,
    7 => bristol7,
    _ => '',
  };

  /// Presets resolve through their language-independent key; custom types
  /// use the user's own name.
  String symptomTypeLabel(SymptomType type) {
    final custom = type.customName;
    if (custom != null) return custom;
    return switch (type.presetKey) {
      'bloating' => symptomBloating,
      'abdominal_pain' => symptomAbdominalPain,
      'nausea' => symptomNausea,
      'gas' => symptomGas,
      'heartburn' => symptomHeartburn,
      'cramps' => symptomCramps,
      'constipation_feeling' => symptomConstipationFeeling,
      'urgency' => symptomUrgency,
      'fatigue' => symptomFatigue,
      'headache' => symptomHeadache,
      final other => other ?? '',
    };
  }
}
