/// Stored by name in the database — add new values at the end, never rename.
enum ScheduleType {
  /// Taken only when needed, no fixed schedule.
  asNeeded,

  /// Taken every day at the times listed in the medication's schedule.
  daily,
}

/// Stored by name in the database — add new values at the end, never rename.
enum IntakeStatus { taken, skipped }
