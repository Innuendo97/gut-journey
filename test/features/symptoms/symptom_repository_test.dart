import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late SymptomRepository repo;

  final day = LocalDay('2026-07-14');

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    repo = SymptomRepository(db, clock.call);
  });

  tearDown(() async {
    await db.close();
  });

  test('lists presets first, then custom types in creation order', () async {
    await repo.addCustomType('Brain fog');
    final types = await repo.watchTypes().first;
    expect(types, hasLength(symptomPresetKeys.length + 1));
    expect(
      types.take(symptomPresetKeys.length).map((t) => t.isPreset),
      everyElement(isTrue),
    );
    expect(types.last.customName, 'Brain fog');
    expect(types.last.isPreset, isFalse);
  });

  test('archiving hides a type unless explicitly included', () async {
    final custom = await repo.addCustomType('Brain fog');
    await repo.setTypeArchived(custom.id, isArchived: true);

    final visible = await repo.watchTypes().first;
    expect(visible.map((t) => t.id), isNot(contains(custom.id)));

    final all = await repo.watchTypes(includeArchived: true).first;
    expect(all.map((t) => t.id), contains(custom.id));
  });

  test('watchByRange spans days inclusively in chronological order', () async {
    for (final (moment, intensity) in [
      (DateTime(2026, 7, 11, 22), 2), // before the range
      (DateTime(2026, 7, 12, 9), 4),
      (DateTime(2026, 7, 13, 21), 6),
      (DateTime(2026, 7, 14, 8), 8), // after the range
    ]) {
      await repo.addEntry(
        symptomTypeId: symptomPresetId('bloating'),
        intensity: intensity,
        occurredAt: moment,
      );
    }

    final range = DateRange(LocalDay('2026-07-12'), LocalDay('2026-07-13'));
    final entries = await repo.watchByRange(range).first;
    expect(entries.map((e) => e.intensity), [4, 6]);
  });

  test('adds, updates and deletes entries with day bucketing', () async {
    final id = await repo.addEntry(
      symptomTypeId: symptomPresetId('bloating'),
      intensity: 5,
      occurredAt: DateTime(2026, 7, 14, 15),
      durationMinutes: 30,
    );

    var entries = await repo.watchByDay(day).first;
    expect(entries.single.intensity, 5);
    expect(entries.single.durationMinutes, 30);

    await repo.updateEntry(
      entries.single.copyWith(
        intensity: 8,
        occurredAt: DateTime(2026, 7, 15, 1), // past midnight → next day
      ),
    );

    expect(await repo.watchByDay(day).first, isEmpty);
    entries = await repo.watchByDay(LocalDay('2026-07-15')).first;
    expect(entries.single.intensity, 8);

    await repo.deleteEntry(id);
    expect(await repo.watchByDay(LocalDay('2026-07-15')).first, isEmpty);
  });
}
