// The self-reference inside check() is the documented drift pattern for
// column constraints, not a real recursive getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';

@TableIndex(name: 'idx_bowel_entries_local_day', columns: {#localDay})
@TableIndex(name: 'idx_bowel_entries_occurred_at', columns: {#occurredAt})
@DataClassName('BowelEntryRow')
class BowelEntries extends Table with AuditColumns, EntryColumns {
  /// Bristol Stool Scale, 1 (hard lumps) to 7 (liquid).
  IntColumn get bristolType =>
      integer().check(bristolType.isBetweenValues(1, 7))();
  BoolColumn get urgency => boolean().withDefault(const Constant(false))();
  IntColumn get pain =>
      integer().nullable().check(pain.isBetweenValues(1, 10))();
  BoolColumn get blood => boolean().withDefault(const Constant(false))();
  BoolColumn get mucus => boolean().withDefault(const Constant(false))();
  BoolColumn get incompleteEvacuation =>
      boolean().withDefault(const Constant(false))();
}
