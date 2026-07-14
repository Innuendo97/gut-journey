import 'package:drift/drift.dart';

/// Columns every persisted record carries: a UUID primary key plus audit
/// timestamps (UTC), which double as the change markers a future sync layer
/// needs.
mixin AuditColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Columns shared by diary entries: the moment the event happened (UTC,
/// user-editable) and the local calendar day it belongs to, captured at
/// write time (see `LocalDay` in `core/domain`).
mixin EntryColumns on Table {
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get localDay => text().withLength(min: 10, max: 10)();
  TextColumn get notes => text().nullable()();
}
