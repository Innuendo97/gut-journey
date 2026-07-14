// The self-reference inside check() is the documented drift pattern for
// column constraints, not a real recursive getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';

/// Symptom vocabulary: seeded presets (identified by a language-independent
/// `preset_key`, localized in the UI) plus user-defined custom types.
@DataClassName('SymptomTypeRow')
class SymptomTypes extends Table {
  TextColumn get id => text()();
  TextColumn get presetKey => text().nullable().unique()();
  TextColumn get customName => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Exactly one of preset_key / custom_name must be set.
    'CHECK ((preset_key IS NULL) != (custom_name IS NULL))',
  ];
}

@TableIndex(name: 'idx_symptom_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_symptom_entries_occurred_at', columns: {#occurredAt})
@DataClassName('SymptomEntryRow')
class SymptomEntries extends Table with AuditColumns, EntryColumns {
  TextColumn get symptomTypeId =>
      text().references(SymptomTypes, #id, onDelete: KeyAction.restrict)();
  IntColumn get intensity =>
      integer().check(intensity.isBetweenValues(1, 10))();
  IntColumn get durationMinutes => integer().nullable()();
}
