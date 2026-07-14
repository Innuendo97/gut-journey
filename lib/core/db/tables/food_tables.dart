import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';

/// The user's personal food library: foods are created the first time they
/// are typed and reused through autocomplete afterwards.
@DataClassName('FoodItemRow')
class FoodItems extends Table with AuditColumns {
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Usage stats drive autocomplete ranking.
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Namespaced key/value attributes attached to a food, e.g.
/// `(source: 'fodmap', key: 'fructan_level', value: 'high')`.
///
/// This is the hook that lets external food databases (FODMAP
/// classifications, allergen lists, …) plug in later without schema changes,
/// while staying queryable in correlation JOINs.
@DataClassName('FoodAttributeRow')
class FoodAttributes extends Table {
  TextColumn get id => text()();
  TextColumn get foodItemId =>
      text().references(FoodItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get source => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {foodItemId, source, key},
  ];
}
