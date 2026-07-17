import 'package:drift/drift.dart';
import 'package:gut_journey/core/db/tables/columns.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';

/// Reintroduction tests of FODMAP groups (added in schema v2). Day columns
/// hold `YYYY-MM-DD` local days like every diary bucket; the symptoms
/// observed during a test live in the regular diary tables.
@TableIndex(name: 'idx_fodmap_challenges_start_day', columns: {#startDay})
@DataClassName('FodmapChallengeRow')
class FodmapChallenges extends Table with AuditColumns {
  TextColumn get fodmapGroup => textEnum<FodmapGroup>()();
  TextColumn get status => textEnum<ChallengeStatus>()();
  TextColumn get startDay => text().withLength(min: 10, max: 10)();
  TextColumn get testEndDay => text().withLength(min: 10, max: 10).nullable()();
  TextColumn get completedDay =>
      text().withLength(min: 10, max: 10).nullable()();
  TextColumn get outcome => textEnum<ObservedOutcome>().nullable()();
  TextColumn get outcomeNote => text().nullable()();
}
