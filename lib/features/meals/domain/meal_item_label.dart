import 'package:gut_journey/features/meals/domain/meal_entry.dart';

/// "Pasta 120 g" when the amount is known, just the name otherwise —
/// precise meals read at a glance wherever items are listed.
String mealItemLabel(MealItem item) {
  final amount = item.amountG;
  if (amount == null) return item.food.name;
  final grams = amount == amount.roundToDouble()
      ? '${amount.round()}'
      : '$amount';
  return '${item.food.name} $grams g';
}
