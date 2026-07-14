import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

part 'meal_entry.freezed.dart';
part 'meal_entry.g.dart';

/// An eating event with the foods it contained.
@freezed
abstract class MealEntry with _$MealEntry {
  const factory MealEntry({
    required String id,
    required MealType type,
    required DateTime occurredAt,
    required LocalDay day,
    required List<MealItem> items,
    String? notes,
  }) = _MealEntry;

  factory MealEntry.fromJson(Map<String, dynamic> json) =>
      _$MealEntryFromJson(json);
}

/// One food within a meal.
@freezed
abstract class MealItem with _$MealItem {
  const factory MealItem({
    required FoodItem food,
    String? portionDescription,
  }) = _MealItem;

  factory MealItem.fromJson(Map<String, dynamic> json) =>
      _$MealItemFromJson(json);
}

/// Input for creating or editing a meal item: either an existing library
/// food or a new name typed inline (the library entry is created on save).
@freezed
sealed class MealItemInput with _$MealItemInput {
  const factory MealItemInput.existing({
    required String foodItemId,
    String? portionDescription,
  }) = ExistingFoodInput;

  const factory MealItemInput.newFood({
    required String name,
    String? portionDescription,
  }) = NewFoodInput;
}
