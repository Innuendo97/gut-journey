import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:meta/meta.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) =>
      BackupRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

enum BackupError {
  /// The picked file is not a Gut Journey SQLite backup.
  notABackup,

  /// The backup was written by a newer app version (higher schema version).
  newerSchema,
}

class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException(${error.name})';
}

/// Exports and restores the whole database.
///
/// The backup format is the SQLite database file itself (snapshotted with
/// `VACUUM INTO`, so it is transaction-consistent and compacted). Restoring
/// first migrates the backup to the current schema, then swaps the live
/// database contents for the backup's inside one transaction.
class BackupRepository {
  // Public parameter names so test fakes can use super parameters.
  BackupRepository(AppDatabase db, Clock clock) : _db = db, _clock = clock;

  final AppDatabase _db;
  final Clock _clock;

  /// Tables the earliest released schema already had — used to recognise a
  /// Gut Journey database before migrating it. Never remove entries.
  static const _sentinelTables = {
    'food_items',
    'meal_entries',
    'symptom_types',
    'bowel_entries',
  };

  static const _sqliteMagic = 'SQLite format 3\u0000';

  /// All tables, parents before children, so restore can insert in order
  /// (and delete in reverse) without violating foreign keys.
  @visibleForTesting
  List<TableInfo<Table, dynamic>> get orderedTables => [
    _db.foodItems,
    _db.foodAttributes,
    _db.symptomTypes,
    _db.medications,
    _db.mealEntries,
    _db.mealEntryItems,
    _db.symptomEntries,
    _db.bowelEntries,
    _db.weightEntries,
    _db.waterEntries,
    _db.sleepEntries,
    _db.activityEntries,
    _db.medicationIntakes,
  ];

  /// A transaction-consistent snapshot of the database file.
  Future<Uint8List> exportDatabaseBytes() async {
    final dir = await Directory.systemTemp.createTemp('gut_journey_export');
    try {
      final target = '${dir.path}/backup.db';
      await _db.customStatement('VACUUM INTO ?', [target]);
      return await File(target).readAsBytes();
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// All data as a versioned, human-readable JSON document (export only —
  /// restore goes through the database backup).
  Future<String> exportJsonString() async {
    const serializer = ValueSerializer.defaults(
      serializeDateTimeValuesAsString: true,
    );
    final data = <String, Object?>{};
    for (final table in orderedTables) {
      final rows = await _db.select(table).get();
      data[table.actualTableName] = [
        for (final row in rows)
          (row as DataClass).toJson(serializer: serializer),
      ];
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'gut-journey-export',
      'schemaVersion': _db.schemaVersion,
      'exportedAt': _clock().toUtc().toIso8601String(),
      'data': data,
    });
  }

  /// Replaces all current data with the contents of the backup at
  /// [sourcePath].
  ///
  /// Works on a temporary copy (the user's file is never touched), migrates
  /// backups from older app versions to the current schema, and throws
  /// [BackupException] on files that are not valid Gut Journey backups.
  Future<void> restoreDatabase(String sourcePath) async {
    await _ensureSqliteFile(File(sourcePath));
    final dir = await Directory.systemTemp.createTemp('gut_journey_restore');
    try {
      final temp = await File(sourcePath).copy('${dir.path}/restore.db');
      await _validateBackup(temp.path);
      await _migrateBackup(temp);
      await _swapContents(temp.path);
    } on BackupException {
      rethrow;
    } on Exception {
      // Corrupt files can pass the header check and still blow up on
      // ATTACH, migration or the copy; the live data is safe either way
      // (the swap is transactional).
      throw const BackupException(BackupError.notABackup);
    } finally {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _ensureSqliteFile(File file) async {
    if (!file.existsSync()) throw const BackupException(BackupError.notABackup);
    final raf = await file.open();
    try {
      final header = await raf.read(_sqliteMagic.length);
      if (String.fromCharCodes(header) != _sqliteMagic) {
        throw const BackupException(BackupError.notABackup);
      }
    } finally {
      await raf.close();
    }
  }

  /// Checks schema version and sentinel tables through a temporary ATTACH,
  /// before any migration code runs on the file.
  Future<void> _validateBackup(String path) async {
    await _db.customStatement('ATTACH DATABASE ? AS backup_src', [path]);
    try {
      final versionRow = await _db
          .customSelect('PRAGMA backup_src.user_version')
          .getSingle();
      final version = versionRow.read<int>('user_version');
      if (version > _db.schemaVersion) {
        throw const BackupException(BackupError.newerSchema);
      }
      final tableRows = await _db
          .customSelect(
            "SELECT name FROM backup_src.sqlite_master WHERE type = 'table'",
          )
          .get();
      final tables = {for (final row in tableRows) row.read<String>('name')};
      if (version < 1 || !tables.containsAll(_sentinelTables)) {
        throw const BackupException(BackupError.notABackup);
      }
    } finally {
      await _db.customStatement('DETACH DATABASE backup_src');
    }
  }

  /// Opens the copied backup as an [AppDatabase], which runs the step
  /// migrations and leaves the file at the current schema version.
  Future<void> _migrateBackup(File file) async {
    final backupDb = AppDatabase(NativeDatabase(file));
    try {
      // Any statement forces the database open, and with it the migration.
      await backupDb.customSelect('SELECT 1').get();
    } finally {
      await backupDb.close();
    }
  }

  Future<void> _swapContents(String path) async {
    // ATTACH is not allowed inside a transaction, so it brackets one.
    await _db.customStatement('ATTACH DATABASE ? AS backup_src', [path]);
    try {
      await _db.transaction(() async {
        for (final table in orderedTables.reversed) {
          await _db.customStatement(
            'DELETE FROM main."${table.actualTableName}"',
          );
        }
        for (final table in orderedTables) {
          // Explicit column lists: a migrated backup may order columns
          // differently from a freshly created database.
          final columns = [
            for (final column in table.$columns) '"${column.name}"',
          ].join(', ');
          await _db.customStatement(
            'INSERT INTO main."${table.actualTableName}" ($columns) '
            'SELECT $columns FROM backup_src."${table.actualTableName}"',
          );
        }
      });
    } finally {
      await _db.customStatement('DETACH DATABASE backup_src');
    }
    // customStatement bypasses drift's update tracking; wake up the streams.
    _db.markTablesUpdated(_db.allTables);
  }
}
