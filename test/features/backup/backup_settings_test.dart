import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/backup/data/backup_files.dart';
import 'package:gut_journey/features/backup/data/backup_repository.dart';

import '../../helpers/pump_app.dart';

/// Records saves and returns a canned pick, instead of opening dialogs.
class FakeBackupFiles extends BackupFiles {
  FakeBackupFiles({this.pickResult});

  final String? pickResult;
  final saves = <(String, Uint8List)>[];

  @override
  Future<bool> saveAs({
    required String fileName,
    required Uint8List bytes,
  }) async {
    saves.add((fileName, bytes));
    return true;
  }

  @override
  Future<String?> pickBackupFile() async => pickResult;
}

/// The real repository does file IO, which never completes under the fake
/// async of widget tests — the UI is wired against this stand-in instead.
class FakeBackupRepository extends BackupRepository {
  FakeBackupRepository(
    super.db,
    super.clock, {
    required this.restoredPaths,
    this.restoreError,
  });

  final BackupException? restoreError;
  final List<String> restoredPaths;

  @override
  Future<Uint8List> exportDatabaseBytes() async =>
      Uint8List.fromList([1, 2, 3]);

  @override
  Future<String> exportJsonString() async => '{"fake": true}';

  @override
  Future<void> restoreDatabase(String sourcePath) async {
    final error = restoreError;
    if (error != null) throw error;
    restoredPaths.add(sourcePath);
  }
}

/// Registers a [testApp] with fresh backup fakes, already on the Settings
/// screen. The `restored` list collects the paths passed to restoreDatabase.
void testBackup(
  String description, {
  required Future<void> Function(
    WidgetTester tester,
    FakeBackupFiles files,
    List<String> restored,
  )
  body,
  String? pickResult,
  BackupException? restoreError,
}) {
  final files = FakeBackupFiles(pickResult: pickResult);
  final restored = <String>[];
  testApp(
    description,
    overrides: [
      backupFilesProvider.overrideWithValue(files),
      backupRepositoryProvider.overrideWith(
        (ref) => FakeBackupRepository(
          ref.watch(databaseProvider),
          ref.watch(clockProvider),
          restoredPaths: restored,
          restoreError: restoreError,
        ),
      ),
    ],
    (tester, harness) async {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await body(tester, files, restored);
    },
  );
}

void main() {
  testBackup(
    'exporting a backup saves a dated database file',
    body: (tester, files, restored) async {
      await tapInSheet(tester, 'Export backup');

      expect(files.saves, hasLength(1));
      final (fileName, bytes) = files.saves.single;
      expect(fileName, 'gut-journey-backup-2026-07-14.db');
      expect(bytes, [1, 2, 3]);
      expect(find.text('Backup saved'), findsOneWidget);
    },
  );

  testBackup(
    'exporting JSON saves a dated json file',
    body: (tester, files, restored) async {
      await tapInSheet(tester, 'Export data as JSON');

      final (fileName, bytes) = files.saves.single;
      expect(fileName, 'gut-journey-export-2026-07-14.json');
      expect(String.fromCharCodes(bytes), '{"fake": true}');
      expect(find.text('Export saved'), findsOneWidget);
    },
  );

  testBackup(
    'restoring asks for confirmation before touching the database',
    pickResult: '/backups/my-backup.db',
    body: (tester, files, restored) async {
      // The tile sits below the fold now that Settings also hosts the
      // kcal goal — bring it on screen before tapping.
      await tester.scrollUntilVisible(
        find.text('Restore from backup'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapInSheet(tester, 'Restore from backup');

      expect(find.text('Restore backup?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(restored, isEmpty);

      await tapInSheet(tester, 'Restore from backup');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(restored, ['/backups/my-backup.db']);
      expect(find.text('Backup restored'), findsOneWidget);
    },
  );

  testBackup(
    'restore errors surface as readable messages',
    pickResult: '/backups/random-file.txt',
    restoreError: const BackupException(BackupError.notABackup),
    body: (tester, files, restored) async {
      await tester.scrollUntilVisible(
        find.text('Restore from backup'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapInSheet(tester, 'Restore from backup');
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(
        find.text('This file is not a Gut Journey backup.'),
        findsOneWidget,
      );
    },
  );
}
