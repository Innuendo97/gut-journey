import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) =>
      FoodRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// The personal food library: foods created on first use and ranked for
/// autocomplete by favorites and usage.
class FoodRepository {
  FoodRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<FoodItem>> watchLibrary({String? query}) {
    final statement = _db.select(_db.foodItems);
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      statement.where((t) => t.name.contains(trimmed));
    }
    statement.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return statement.watch().map(_toDomainList);
  }

  /// Autocomplete: prefix matches ranked favorites first, then most used,
  /// then most recently used. An empty [prefix] returns the top-ranked foods
  /// ("recents" for the meal sheet).
  Future<List<FoodItem>> suggest(String prefix, {int limit = 10}) async {
    final trimmed = prefix.trim();
    final statement = _db.select(_db.foodItems)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isFavorite),
        (t) => OrderingTerm.desc(t.usageCount),
        (t) => OrderingTerm.desc(t.lastUsedAt),
        (t) => OrderingTerm.asc(t.name),
      ])
      ..limit(limit);
    if (trimmed.isNotEmpty) {
      statement.where((t) => t.name.like('$trimmed%'));
    }
    return _toDomainList(await statement.get());
  }

  Future<FoodItem> create(String name, {String? category}) async {
    final now = _clock().toUtc();
    final item = FoodItem(
      id: newEntryId(),
      name: name.trim(),
      category: category,
    );
    await _db
        .into(_db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: item.id,
            name: item.name,
            category: Value(category),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return item;
  }

  /// Case-insensitive lookup by name, creating the food if it doesn't exist —
  /// this is how typing an unknown food in the meal sheet grows the library.
  Future<FoodItem> getOrCreateByName(String name) async {
    final trimmed = name.trim();
    final existing =
        await (_db.select(_db.foodItems)
              ..where((t) => t.name.lower().equals(trimmed.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.toDomain();
    return create(trimmed);
  }

  Future<void> updateItem(FoodItem item) async {
    await (_db.update(_db.foodItems)..where((t) => t.id.equals(item.id))).write(
      FoodItemsCompanion(
        name: Value(item.name.trim()),
        category: Value(item.category),
        isFavorite: Value(item.isFavorite),
        notes: Value(item.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> setFavorite(String id, {required bool isFavorite}) async {
    await (_db.update(_db.foodItems)..where((t) => t.id.equals(id))).write(
      FoodItemsCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  /// Bumps autocomplete ranking stats for the foods of a saved meal.
  Future<void> recordUsage(List<String> foodItemIds, DateTime when) async {
    await _db.transaction(() async {
      for (final id in foodItemIds) {
        await _db.customUpdate(
          'UPDATE food_items SET usage_count = usage_count + 1 WHERE id = ?',
          variables: [Variable.withString(id)],
          updates: {_db.foodItems},
        );
        await (_db.update(_db.foodItems)..where((t) => t.id.equals(id))).write(
          FoodItemsCompanion(lastUsedAt: Value(when.toUtc())),
        );
      }
    });
  }

  /// Deletes a food if no meal references it. Returns false (and leaves the
  /// food in place) when it is still in use.
  Future<bool> delete(String id) async {
    final usages = _db.mealEntryItems.foodItemId.count();
    final used =
        await (_db.selectOnly(_db.mealEntryItems)
              ..addColumns([usages])
              ..where(_db.mealEntryItems.foodItemId.equals(id)))
            .map((row) => row.read(usages) ?? 0)
            .getSingle();
    if (used > 0) return false;
    await (_db.delete(_db.foodItems)..where((t) => t.id.equals(id))).go();
    return true;
  }

  /// Sets a namespaced attribute (e.g. source `fodmap`, key `overall`,
  /// value `high`) — the extension point for external food databases.
  Future<void> setAttribute({
    required String foodItemId,
    required String source,
    required String key,
    required String value,
  }) async {
    await _db
        .into(_db.foodAttributes)
        .insert(
          FoodAttributesCompanion.insert(
            id: newEntryId(),
            foodItemId: foodItemId,
            source: source,
            key: key,
            value: value,
          ),
          onConflict: DoUpdate(
            (old) => FoodAttributesCompanion(value: Value(value)),
            target: [
              _db.foodAttributes.foodItemId,
              _db.foodAttributes.source,
              _db.foodAttributes.key,
            ],
          ),
        );
  }

  /// All attributes of a food under one [source], as a key → value map.
  Future<Map<String, String>> getAttributes(
    String foodItemId, {
    required String source,
  }) async {
    final rows =
        await (_db.select(_db.foodAttributes)..where(
              (t) => t.foodItemId.equals(foodItemId) & t.source.equals(source),
            ))
            .get();
    return {for (final row in rows) row.key: row.value};
  }

  List<FoodItem> _toDomainList(List<FoodItemRow> rows) => [
    for (final row in rows) row.toDomain(),
  ];
}

extension FoodItemRowToDomain on FoodItemRow {
  FoodItem toDomain() => FoodItem(
    id: id,
    name: name,
    category: category,
    isFavorite: isFavorite,
    usageCount: usageCount,
    lastUsedAt: lastUsedAt,
    notes: notes,
  );
}
