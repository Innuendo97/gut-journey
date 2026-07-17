import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';
import 'package:gut_journey/core/db/tables/food_tables.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';

@TableIndex(name: 'idx_meal_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_meal_entries_occurred_at', columns: {#occurredAt})
@DataClassName('MealEntryRow')
class MealEntries extends Table with AuditColumns, EntryColumns {
  TextColumn get mealType => textEnum<MealType>()();
}

/// Foods eaten in a meal — a many-to-many link, so future food↔symptom
/// correlations are JOINs instead of free-text parsing.
@DataClassName('MealEntryItemRow')
class MealEntryItems extends Table {
  TextColumn get id => text()();
  TextColumn get mealEntryId =>
      text().references(MealEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get foodItemId =>
      text().references(FoodItems, #id, onDelete: KeyAction.restrict)();
  TextColumn get portionDescription => text().nullable()();

  /// Number of typical servings eaten; null means one serving.
  RealColumn get quantity => real().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
