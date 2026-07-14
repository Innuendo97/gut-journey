import 'package:freezed_annotation/freezed_annotation.dart';

part 'food_item.freezed.dart';
part 'food_item.g.dart';

/// An item of the user's personal food library.
@freezed
abstract class FoodItem with _$FoodItem {
  const factory FoodItem({
    required String id,
    required String name,
    String? category,
    @Default(false) bool isFavorite,
    @Default(0) int usageCount,
    DateTime? lastUsedAt,
    String? notes,
  }) = _FoodItem;

  factory FoodItem.fromJson(Map<String, dynamic> json) =>
      _$FoodItemFromJson(json);
}
