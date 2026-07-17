import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepository(
    ref.watch(databaseProvider),
    ref.watch(foodRepositoryProvider),
  ),
);

/// User-entered nutrition estimates and the calorie aggregates built on
/// them. Facts live in the namespaced `food_attributes` table (same
/// pattern as the FODMAP tags); nothing here is medical advice — totals
/// are estimates from the user's own per-serving values.
class NutritionRepository {
  NutritionRepository(this._db, this._foods);

  final AppDatabase _db;
  final FoodRepository _foods;

  Future<NutritionFacts> getFacts(String foodItemId) async =>
      NutritionFacts.fromAttributes(
        await _foods.getAttributes(
          foodItemId,
          source: nutritionAttributeSource,
        ),
      );

  /// Persists [facts] key by key: present values upsert their attribute
  /// row, absent ones delete it — so clearing a field in the editor
  /// removes the stored estimate.
  Future<void> saveFacts(String foodItemId, NutritionFacts facts) async {
    final values = facts.toAttributes();
    for (final key in nutritionAttributeKeys) {
      final value = values[key];
      if (value != null) {
        await _foods.setAttribute(
          foodItemId: foodItemId,
          source: nutritionAttributeSource,
          key: key,
          value: value,
        );
      } else {
        await _foods.removeAttribute(
          foodItemId: foodItemId,
          source: nutritionAttributeSource,
          key: key,
        );
      }
    }
  }

  /// foodItemId → kcal per serving for the whole library, live.
  /// Unparseable stored values are dropped.
  Stream<Map<String, double>> watchKcalByFood() => _foods
      .watchAttributeValues(
        source: nutritionAttributeSource,
        key: nutritionKcalKey,
      )
      .map(
        (values) => {
          for (final entry in values.entries)
            if (double.tryParse(entry.value) != null)
              entry.key: double.parse(entry.value),
        },
      );

  /// Estimated kcal per day over [range]: sum of kcal-per-serving ×
  /// servings for every logged meal item whose food has a kcal estimate.
  /// Foods without one are excluded by the join; days without any
  /// kcal-bearing item emit no value at all (no data ≠ zero). The watch
  /// spans meals, items and attributes, so editing an estimate live-updates
  /// every total retroactively.
  Stream<List<DailyValue>> watchKcalDaily(DateRange range) {
    final items = _db.mealEntryItems;
    final meals = _db.mealEntries;
    final attrs = _db.foodAttributes;
    // CAST(value AS REAL): unparseable text becomes 0, contributing
    // nothing instead of crashing the query.
    final kcalPerServing = attrs.value.cast<double>();
    final servings = coalesce<double>([items.quantity, const Constant(1)]);
    final total = (kcalPerServing * servings).sum();
    final query =
        _db.selectOnly(items).join([
            innerJoin(
              meals,
              meals.id.equalsExp(items.mealEntryId),
              useColumns: false,
            ),
            innerJoin(
              attrs,
              attrs.foodItemId.equalsExp(items.foodItemId) &
                  attrs.source.equals(nutritionAttributeSource) &
                  attrs.key.equals(nutritionKcalKey),
              useColumns: false,
            ),
          ])
          ..addColumns([meals.localDay, total])
          ..where(
            meals.localDay.isBetweenValues(range.start.value, range.end.value),
          )
          ..groupBy([meals.localDay])
          ..orderBy([OrderingTerm.asc(meals.localDay)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          DailyValue(
            LocalDay(row.read(meals.localDay)!),
            row.read(total) ?? 0,
          ),
      ],
    );
  }

  /// Estimated kcal for one day, or null when no logged food that day has
  /// a kcal estimate — the "hide the card entirely" signal for Today.
  Stream<double?> watchDayKcal(LocalDay day) => watchKcalDaily(
    DateRange(day, day),
  ).map((values) => values.isEmpty ? null : values.first.value);
}
