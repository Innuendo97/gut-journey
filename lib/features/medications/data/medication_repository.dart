import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/entry_id.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => MedicationRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);

class MedicationRepository {
  MedicationRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Stream<List<Medication>> watchAll({bool activeOnly = false}) {
    final statement = _db.select(_db.medications);
    if (activeOnly) {
      statement.where((t) => t.isActive.equals(true));
    }
    statement.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  Future<String> createMedication({
    required String name,
    required ScheduleType scheduleType,
    required LocalDay startDay,
    List<String> scheduledTimes = const [],
    String? dosage,
    LocalDay? endDay,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.medications)
        .insert(
          MedicationsCompanion.insert(
            id: id,
            name: name.trim(),
            scheduleType: scheduleType,
            scheduledTimes: Value(scheduledTimes),
            dosage: Value(dosage),
            startDay: startDay.value,
            endDay: Value(endDay?.value),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateMedication(Medication medication) async {
    await (_db.update(
      _db.medications,
    )..where((t) => t.id.equals(medication.id))).write(
      MedicationsCompanion(
        name: Value(medication.name.trim()),
        scheduleType: Value(medication.scheduleType),
        scheduledTimes: Value(medication.scheduledTimes),
        dosage: Value(medication.dosage),
        startDay: Value(medication.startDay.value),
        endDay: Value(medication.endDay?.value),
        isActive: Value(medication.isActive),
        notes: Value(medication.notes),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> setActive(String id, {required bool isActive}) async {
    await (_db.update(_db.medications)..where((t) => t.id.equals(id))).write(
      MedicationsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  /// Removes the medication and, via ON DELETE CASCADE, its intake history.
  Future<void> deleteMedication(String id) async {
    await (_db.delete(_db.medications)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<MedicationIntake>> watchIntakesByDay(LocalDay day) {
    final statement = _db.select(_db.medicationIntakes)
      ..where((t) => t.localDay.equals(day.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
    return statement.watch().map(
      (rows) => [for (final row in rows) row.toDomain()],
    );
  }

  /// Intakes between [from] and [to] (inclusive) — input for adherence.
  Future<List<MedicationIntake>> intakesBetween(
    LocalDay from,
    LocalDay to,
  ) async {
    return _intakesBetweenQuery(from, to).get().then(_toDomainList);
  }

  /// Watch variant of [intakesBetween], used by live adherence stats.
  Stream<List<MedicationIntake>> watchIntakesBetween(
    LocalDay from,
    LocalDay to,
  ) {
    return _intakesBetweenQuery(from, to).watch().map(_toDomainList);
  }

  SimpleSelectStatement<$MedicationIntakesTable, MedicationIntakeRow>
  _intakesBetweenQuery(LocalDay from, LocalDay to) {
    return _db.select(_db.medicationIntakes)
      ..where((t) => t.localDay.isBetweenValues(from.value, to.value))
      ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]);
  }

  List<MedicationIntake> _toDomainList(List<MedicationIntakeRow> rows) => [
    for (final row in rows) row.toDomain(),
  ];

  Future<String> logIntake({
    required String medicationId,
    required IntakeStatus status,
    required DateTime occurredAt,
    String? scheduledTime,
    String? notes,
  }) async {
    final id = newEntryId();
    final now = _clock().toUtc();
    await _db
        .into(_db.medicationIntakes)
        .insert(
          MedicationIntakesCompanion.insert(
            id: id,
            medicationId: medicationId,
            status: status,
            scheduledTime: Value(scheduledTime),
            occurredAt: occurredAt.toUtc(),
            localDay: LocalDay.fromDateTime(occurredAt).value,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> deleteIntake(String id) async {
    await (_db.delete(
      _db.medicationIntakes,
    )..where((t) => t.id.equals(id))).go();
  }
}

extension MedicationRowToDomain on MedicationRow {
  Medication toDomain() => Medication(
    id: id,
    name: name,
    scheduleType: scheduleType,
    scheduledTimes: scheduledTimes,
    dosage: dosage,
    startDay: LocalDay(startDay),
    endDay: endDay == null ? null : LocalDay(endDay!),
    isActive: isActive,
    notes: notes,
  );
}

extension MedicationIntakeRowToDomain on MedicationIntakeRow {
  MedicationIntake toDomain() => MedicationIntake(
    id: id,
    medicationId: medicationId,
    status: status,
    scheduledTime: scheduledTime,
    occurredAt: occurredAt,
    day: LocalDay(localDay),
    notes: notes,
  );
}
