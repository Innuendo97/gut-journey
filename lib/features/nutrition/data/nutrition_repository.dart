import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';

/// A food's kcal figure for list subtitles, with the base it refers to.
typedef KcalEstimate = ({double kcal, bool per100});

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

  /// foodItemId → displayable kcal estimate for the whole library, live:
  /// the per-100g base when present, the legacy per-serving value
  /// otherwise. Unparseable stored values are dropped.
  Stream<Map<String, KcalEstimate>> watchKcalByFood() {
    final query = _db.select(_db.foodAttributes)
      ..where(
        (t) =>
            t.source.equals(nutritionAttributeSource) &
            t.key.isIn(const [nutritionKcal100Key, nutritionKcalKey]),
      );
    return query.watch().map((rows) {
      final result = <String, KcalEstimate>{};
      for (final row in rows) {
        final kcal = double.tryParse(row.value);
        if (kcal == null) continue;
        final per100 = row.key == nutritionKcal100Key;
        final current = result[row.foodItemId];
        if (current == null || (per100 && !current.per100)) {
          result[row.foodItemId] = (kcal: kcal, per100: per100);
        }
      }
      return result;
    });
  }

  /// Estimated kcal per day over [range], mirroring
  /// [NutritionFacts.nutrientsFor] in SQL: items with an explicit amount
  /// scale the food's per-100g base, historical items (null amount) keep
  /// the legacy per-serving × servings formula. Items whose food lacks the
  /// base their formula needs are excluded; days without any kcal-bearing
  /// item emit no value at all (no data ≠ zero). The watch spans meals,
  /// items and attributes, so editing an estimate live-updates every total
  /// retroactively.
  Stream<List<DailyValue>> watchKcalDaily(DateRange range) {
    final items = _db.mealEntryItems;
    final meals = _db.mealEntries;
    final a100 = _db.alias(_db.foodAttributes, 'a100');
    final aServ = _db.alias(_db.foodAttributes, 'a_serv');
    // CAST(value AS REAL): unparseable text becomes 0, contributing
    // nothing instead of crashing the query.
    final kcal100 = a100.value.cast<double>();
    final kcalPerServing = aServ.value.cast<double>();
    final servings = coalesce<double>([items.quantity, const Constant(1)]);
    // The grams product is NULL whenever amountG or the per-100g base is
    // missing, so COALESCE falls through to the legacy formula exactly for
    // historical rows — the WHERE below drops the rows neither covers.
    final gramsKcal = (kcal100 * items.amountG) / const Constant(100);
    final itemKcal = coalesce<double>([
      gramsKcal,
      kcalPerServing * servings,
    ]);
    final total = itemKcal.sum();
    final query =
        _db.selectOnly(items).join([
            innerJoin(
              meals,
              meals.id.equalsExp(items.mealEntryId),
              useColumns: false,
            ),
            leftOuterJoin(
              a100,
              a100.foodItemId.equalsExp(items.foodItemId) &
                  a100.source.equals(nutritionAttributeSource) &
                  a100.key.equals(nutritionKcal100Key),
              useColumns: false,
            ),
            leftOuterJoin(
              aServ,
              aServ.foodItemId.equalsExp(items.foodItemId) &
                  aServ.source.equals(nutritionAttributeSource) &
                  aServ.key.equals(nutritionKcalKey),
              useColumns: false,
            ),
          ])
          ..addColumns([meals.localDay, total])
          ..where(
            meals.localDay.isBetweenValues(
                  range.start.value,
                  range.end.value,
                ) &
                ((items.amountG.isNotNull() & a100.value.isNotNull()) |
                    (items.amountG.isNull() & aServ.value.isNotNull())),
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
