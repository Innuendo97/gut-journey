import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/backup/data/backup_files.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/report/data/report_data_repository.dart';
import 'package:gut_journey/features/report/data/report_sharer.dart';
import 'package:gut_journey/features/report/domain/report_data.dart';
import 'package:gut_journey/features/stats/data/stats_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';

import '../../helpers/pump_app.dart';

/// Records shares instead of opening the platform share sheet (which would
/// throw MissingPluginException in tests).
class FakeReportSharer extends ReportSharer {
  const FakeReportSharer(this.shares);

  final List<(String, Uint8List)> shares;

  @override
  Future<void> share({
    required String fileName,
    required Uint8List bytes,
  }) async {
    shares.add((fileName, bytes));
  }
}

/// Records collect() calls and returns an empty report, so the sheet tests
/// stay fast and can assert what the UI requested.
class FakeReportDataRepository extends ReportDataRepository {
  FakeReportDataRepository({
    required this.requests,
    required super.stats,
    required super.diary,
    required super.symptoms,
    required super.medications,
    required super.nutrition,
  });

  final List<({DateRange range, bool includeDailyLog, int waterGoalMl})>
  requests;

  @override
  Future<ReportData> collect({
    required DateRange range,
    required bool includeDailyLog,
    required int waterGoalMl,
  }) async {
    requests.add((
      range: range,
      includeDailyLog: includeDailyLog,
      waterGoalMl: waterGoalMl,
    ));
    return ReportData(
      range: range,
      symptomIntensity: const {},
      symptomFrequency: const {},
      symptomTypesById: const {},
      bristolDistribution: const {},
      weightDaily: const [],
      waterDaily: const [],
      waterGoalMl: waterGoalMl,
      sleepDaily: const [],
      activityDaily: const [],
      adherence: const [],
      medicationsById: const {},
      days: includeDailyLog ? const [] : null,
    );
  }
}

/// Registers a [testApp] with fresh report fakes.
void testReport(
  String description, {
  required Future<void> Function(
    WidgetTester tester,
    List<(String, Uint8List)> shares,
    FakeBackupFiles files,
    List<({DateRange range, bool includeDailyLog, int waterGoalMl})> requests,
  )
  body,
}) {
  final shares = <(String, Uint8List)>[];
  final files = FakeBackupFiles();
  final requests =
      <({DateRange range, bool includeDailyLog, int waterGoalMl})>[];
  testApp(
    description,
    overrides: [
      reportSharerProvider.overrideWithValue(FakeReportSharer(shares)),
      backupFilesProvider.overrideWithValue(files),
      reportDataRepositoryProvider.overrideWith(
        (ref) => FakeReportDataRepository(
          requests: requests,
          stats: ref.watch(statsRepositoryProvider),
          diary: ref.watch(diaryRepositoryProvider),
          symptoms: ref.watch(symptomRepositoryProvider),
          medications: ref.watch(medicationRepositoryProvider),
          nutrition: ref.watch(nutritionRepositoryProvider),
        ),
      ),
    ],
    (tester, harness) async {
      await body(tester, shares, files, requests);
    },
  );
}

/// Records saves instead of opening the platform save dialog.
class FakeBackupFiles extends BackupFiles {
  FakeBackupFiles();

  final saves = <(String, Uint8List)>[];

  @override
  Future<bool> saveAs({
    required String fileName,
    required Uint8List bytes,
  }) async {
    saves.add((fileName, bytes));
    return true;
  }
}

Future<void> openSettingsSheet(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await tapInSheet(tester, 'Report for your doctor (PDF)');
}

void main() {
  testReport(
    'sharing from Settings builds a PDF over the default 30 days',
    body: (tester, shares, files, requests) async {
      await openSettingsSheet(tester);
      expect(find.text('PDF report'), findsOneWidget);

      final defaultChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '30 days'),
      );
      expect(defaultChip.selected, isTrue);

      await tapInSheet(tester, 'Share');

      final request = requests.single;
      expect(request.includeDailyLog, isFalse);
      expect(request.range.lengthInDays, 30);

      final (fileName, bytes) = shares.single;
      expect(fileName, 'gut-journey-report-2026-06-15-2026-07-14.pdf');
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(files.saves, isEmpty);
      // The sheet pops after sharing.
      expect(find.text('PDF report'), findsNothing);
    },
  );

  testReport(
    'saving a 7-day report with the daily diary included',
    body: (tester, shares, files, requests) async {
      await openSettingsSheet(tester);

      await tapInSheet(tester, '7 days');
      await tapInSheet(tester, 'Include daily diary');
      await tapInSheet(tester, 'Save');

      final request = requests.single;
      expect(request.includeDailyLog, isTrue);
      expect(request.range.lengthInDays, 7);

      final (fileName, bytes) = files.saves.single;
      expect(fileName, 'gut-journey-report-2026-07-08-2026-07-14.pdf');
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(shares, isEmpty);
      expect(find.text('Report saved'), findsOneWidget);
    },
  );

  testReport(
    'the Stats action opens the sheet preselecting the current period',
    body: (tester, shares, files, requests) async {
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export PDF report'));
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '7 days'),
      );
      expect(chip.selected, isTrue);
    },
  );
}
