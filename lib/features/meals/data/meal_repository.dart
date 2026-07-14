import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(
    ref.watch(databaseProvider),
    ref.watch(foodRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

class MealRepository {
  MealRepository(this._db, this._foods, this._clock);

  final AppDatabase _db;
  final FoodRepository _foods;
  final Clock _clock;

  /// Meals of a day with their foods, ordered chronologically. The joined
  /// watch re-emits when entries, items or the referenced foods change.
  Stream<List<MealEntry>> watchByDay(LocalDay day) {
    final query =
        _db.select(_db.mealEntries).join([
            leftOuterJoin(
              _db.mealEntryItems,
              _db.mealEntryItems.mealEntryId.equalsExp(_db.mealEntries.id),
            ),
            leftOuterJoin(
              _db.foodItems,
              _db.foodItems.id.equalsExp(_db.mealEntryItems.foodItemId),
            ),
          ])
          ..where(_db.mealEntries.localDay.equals(day.value))
          ..orderBy([OrderingTerm.asc(_db.mealEntries.occurredAt)]);
    return query.watch().map(_groupRows);
  }

  Future<String> createMeal({
    required MealType type,
    required DateTime occurredAt,
    required List<MealItemInput> items,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db.transaction(() async {
      await _db
          .into(_db.mealEntries)
          .insert(
            MealEntriesCompanion.insert(
              id: id,
              mealType: type,
              occurredAt: occurredAt.toUtc(),
              localDay: LocalDay.fromDateTime(occurredAt).value,
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final foodIds = await _insertItems(id, items);
      await _foods.recordUsage(foodIds, now);
    });
    return id;
  }

  /// Replaces the meal's fields and foods. Usage stats are not re-recorded
  /// on edit, so editing a meal doesn't inflate autocomplete ranking.
  Future<void> updateMeal({
    required String id,
    required MealType type,
    required DateTime occurredAt,
    required List<MealItemInput> items,
    String? notes,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.mealEntries)..where((t) => t.id.equals(id))).write(
        MealEntriesCompanion(
          mealType: Value(type),
          occurredAt: Value(occurredAt.toUtc()),
          localDay: Value(LocalDay.fromDateTime(occurredAt).value),
          notes: Value(notes),
          updatedAt: Value(_clock().toUtc()),
        ),
      );
      await (_db.delete(
        _db.mealEntryItems,
      )..where((t) => t.mealEntryId.equals(id))).go();
      await _insertItems(id, items);
    });
  }

  Future<void> deleteMeal(String id) async {
    // Items go with it via ON DELETE CASCADE.
    await (_db.delete(_db.mealEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<List<String>> _insertItems(
    String mealEntryId,
    List<MealItemInput> items,
  ) async {
    final foodIds = <String>[];
    for (final item in items) {
      final (foodId, portion) = switch (item) {
        ExistingFoodInput(:final foodItemId, :final portionDescription) => (
          foodItemId,
          portionDescription,
        ),
        NewFoodInput(:final name, :final portionDescription) => (
          (await _foods.getOrCreateByName(name)).id,
          portionDescription,
        ),
      };
      await _db
          .into(_db.mealEntryItems)
          .insert(
            MealEntryItemsCompanion.insert(
              id: newEntryId(),
              mealEntryId: mealEntryId,
              foodItemId: foodId,
              portionDescription: Value(portion),
            ),
          );
      foodIds.add(foodId);
    }
    return foodIds;
  }

  List<MealEntry> _groupRows(List<TypedResult> rows) {
    final entries = <String, MealEntry>{};
    for (final row in rows) {
      final entryRow = row.readTable(_db.mealEntries);
      final entry = entries.putIfAbsent(
        entryRow.id,
        () => MealEntry(
          id: entryRow.id,
          type: entryRow.mealType,
          occurredAt: entryRow.occurredAt,
          day: LocalDay(entryRow.localDay),
          items: const [],
          notes: entryRow.notes,
        ),
      );
      final itemRow = row.readTableOrNull(_db.mealEntryItems);
      final foodRow = row.readTableOrNull(_db.foodItems);
      if (itemRow != null && foodRow != null) {
        entries[entryRow.id] = entry.copyWith(
          items: [
            ...entry.items,
            MealItem(
              food: foodRow.toDomain(),
              portionDescription: itemRow.portionDescription,
            ),
          ],
        );
      }
    }
    return entries.values.toList();
  }
}
