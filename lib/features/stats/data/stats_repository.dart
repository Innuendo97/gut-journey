import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';
import 'package:rxdart/rxdart.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(
    ref.watch(databaseProvider),
    ref.watch(medicationRepositoryProvider),
  ),
);

/// Aggregate queries behind every chart. Charts never see SQL; screens never
/// compute aggregates.
class StatsRepository {
  StatsRepository(this._db, this._medications);

  final AppDatabase _db;
  final MedicationRepository _medications;

  /// Average symptom intensity per day, grouped by symptom type id.
  Stream<Map<String, List<DailyValue>>> watchSymptomIntensity(
    DateRange range,
  ) {
    final t = _db.symptomEntries;
    final avg = t.intensity.avg();
    final query = _db.selectOnly(t)
      ..addColumns([t.symptomTypeId, t.localDay, avg])
      ..where(t.localDay.isBetweenValues(range.start.value, range.end.value))
      ..groupBy([t.symptomTypeId, t.localDay])
      ..orderBy([OrderingTerm.asc(t.localDay)]);
    return query.watch().map((rows) {
      final series = <String, List<DailyValue>>{};
      for (final row in rows) {
        series
            .putIfAbsent(row.read(t.symptomTypeId)!, () => [])
            .add(DailyValue(LocalDay(row.read(t.localDay)!), row.read(avg)!));
      }
      return series;
    });
  }

  /// How many times each symptom type was logged in [range], most frequent
  /// first.
  Stream<Map<String, int>> watchSymptomFrequency(DateRange range) {
    final t = _db.symptomEntries;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([t.symptomTypeId, count])
      ..where(t.localDay.isBetweenValues(range.start.value, range.end.value))
      ..groupBy([t.symptomTypeId])
      ..orderBy([OrderingTerm.desc(count)]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(t.symptomTypeId)!: row.read(count) ?? 0,
      },
    );
  }

  /// Bowel movements per Bristol type (1–7) in [range].
  Stream<Map<int, int>> watchBristolDistribution(DateRange range) {
    final t = _db.bowelEntries;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([t.bristolType, count])
      ..where(t.localDay.isBetweenValues(range.start.value, range.end.value))
      ..groupBy([t.bristolType]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.read(t.bristolType)!: row.read(count) ?? 0,
      },
    );
  }

  /// Average weight per day (kg).
  Stream<List<DailyValue>> watchWeightDaily(DateRange range) {
    final t = _db.weightEntries;
    return _dailyAggregate(t, t.localDay, t.weightKg.avg(), range);
  }

  /// Total water per day (ml).
  Stream<List<DailyValue>> watchWaterDaily(DateRange range) {
    final t = _db.waterEntries;
    return _dailyAggregate(
      t,
      t.localDay,
      t.amountMl.sum().cast<double>(),
      range,
    );
  }

  /// Sleep duration per day (minutes).
  Stream<List<DailyValue>> watchSleepDaily(DateRange range) {
    final t = _db.sleepEntries;
    return _dailyAggregate(
      t,
      t.localDay,
      t.durationMinutes.sum().cast<double>(),
      range,
    );
  }

  /// Physical activity per day (minutes).
  Stream<List<DailyValue>> watchActivityDaily(DateRange range) {
    final t = _db.activityEntries;
    return _dailyAggregate(
      t,
      t.localDay,
      t.durationMinutes.sum().cast<double>(),
      range,
    );
  }

  /// Adherence per active medication over [range], recomputed live as doses
  /// are logged.
  Stream<List<(Medication, AdherenceSummary)>> watchAdherence(
    DateRange range,
  ) {
    return CombineLatestStream.combine2(
      _medications.watchAll(activeOnly: true),
      _medications.watchIntakesBetween(range.start, range.end),
      (medications, intakes) => [
        for (final medication in medications)
          (
            medication,
            computeAdherence(
              medication: medication,
              intakes: intakes,
              from: range.start,
              to: range.end,
            ),
          ),
      ],
    );
  }

  Stream<List<DailyValue>> _dailyAggregate(
    TableInfo<Table, dynamic> table,
    GeneratedColumn<String> localDay,
    Expression<double> aggregate,
    DateRange range,
  ) {
    final query = _db.selectOnly<Table, dynamic>(table)
      ..addColumns([localDay, aggregate])
      ..where(localDay.isBetweenValues(range.start.value, range.end.value))
      ..groupBy([localDay])
      ..orderBy([OrderingTerm.asc(localDay)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          DailyValue(LocalDay(row.read(localDay)!), row.read(aggregate) ?? 0),
      ],
    );
  }
}
