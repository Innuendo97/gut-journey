import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/converters/string_list_converter.dart';
import 'package:gut_journey/core/db/tables/columns.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

@DataClassName('MedicationRow')
class Medications extends Table with AuditColumns {
  TextColumn get name => text()();

  /// Free text, e.g. "40 mg" — dosage formats vary too much to structure.
  TextColumn get dosage => text().nullable()();
  TextColumn get scheduleType => textEnum<ScheduleType>()();

  /// "HH:mm" times for [ScheduleType.daily]; empty for as-needed.
  TextColumn get scheduledTimes => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get startDay => text().withLength(min: 10, max: 10)();
  TextColumn get endDay => text().withLength(min: 10, max: 10).nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

@TableIndex(name: 'idx_medication_intakes_local_day', columns: {#localDay})
@TableIndex(name: 'idx_medication_intakes_occurred_at', columns: {#occurredAt})
@DataClassName('MedicationIntakeRow')
class MedicationIntakes extends Table with AuditColumns, EntryColumns {
  TextColumn get medicationId =>
      text().references(Medications, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => textEnum<IntakeStatus>()();

  /// The "HH:mm" schedule slot this intake fulfils, when it was scheduled —
  /// links intakes to expected doses for adherence.
  TextColumn get scheduledTime => text().nullable()();
}
