import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/app/app.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_db.dart';

/// Taps a button on the quick-add bar; labels there can also appear
/// elsewhere on the screen (e.g. the water card title).
Future<void> tapQuickAdd(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(QuickAddBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Scrolls a sheet target into view before tapping it.
Future<void> tapInSheet(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Everything a widget test needs to drive the real app: in-memory database,
/// mocked preferences and a pinned clock.
class TestHarness {
  TestHarness({required this.db, required this.clock});

  final AppDatabase db;
  final FixedClock clock;
}

/// Like [testWidgets], but with the full app pumped against an in-memory
/// database and a clock pinned to midday (stable day bucketing).
///
/// The wrapper unmounts the tree and closes the database at the end of the
/// body: drift schedules zero-duration timers when its query streams are
/// cancelled, and flutter_test asserts no timers are pending right after it
/// disposes the tree — so cleanup must happen inside the test body.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester, TestHarness harness) body, {
  bool onboarded = true,
  // Forces the app language (e.g. 'it') by pre-seeding the persisted
  // setting, without driving the language picker UI.
  String? localeTag,
  // Riverpod 3 does not export the Override type, so it is inexpressible
  // here; the values must still be provider overrides.
  List<Object> overrides = const [],
}) {
  testWidgets(description, (tester) async {
    SharedPreferences.setMockInitialValues({
      // Most tests exercise the diary, not the disclaimer gate.
      if (onboarded) 'onboarding_accepted': true,
      'locale_tag': ?localeTag,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = createTestDatabase();
    final clock = FixedClock(DateTime(2026, 7, 14, 12));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(clock.call),
          ...overrides.cast(),
        ],
        child: const GutJourneyApp(),
      ),
    );
    await tester.pumpAndSettle();

    var bodySucceeded = false;
    try {
      await body(tester, TestHarness(db: db, clock: clock));
      bodySucceeded = true;
    } finally {
      // Teardown choreography for drift under fake async: unmount the tree
      // (cancels stream subscriptions), pump so drift's zero-duration
      // stream-teardown timers fire, then close the database while pumping —
      // close() itself waits on those timers, so awaiting it before pumping
      // would deadlock. pump() without a duration does not advance the fake
      // clock, so the explicit durations matter.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      if (bodySucceeded) {
        final closing = db.close();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 1));
        await closing;
      }
      // On failure the in-memory database is deliberately leaked: closing it
      // in a broken state can deadlock and mask the original assertion.
    }
  });
}
