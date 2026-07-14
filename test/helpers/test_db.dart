import 'package:drift/native.dart';
import 'package:gut_journey/core/db/app_database.dart';

/// A real SQLite database in memory: repository tests exercise actual SQL,
/// constraints and cascades instead of mocks.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// A controllable clock: assign [now] to travel in time.
class FixedClock {
  FixedClock(this.now);

  DateTime now;

  DateTime call() => now;
}
