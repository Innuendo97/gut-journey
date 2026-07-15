import 'package:flutter/material.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

/// One icon per meal type, shared by the timeline and the meal sheet.
IconData mealTypeIcon(MealType type) => switch (type) {
  MealType.breakfast => Icons.free_breakfast_outlined,
  MealType.lunch => Icons.lunch_dining_outlined,
  MealType.dinner => Icons.dinner_dining_outlined,
  MealType.snack => Icons.cookie_outlined,
  MealType.drink => Icons.local_cafe_outlined,
};
