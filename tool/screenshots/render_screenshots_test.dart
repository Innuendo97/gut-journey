// Renders the README screenshots by pumping the real app (in-memory
// database, demo dataset, real Roboto/MaterialIcons fonts) at phone size —
// no emulator needed. NOT part of the regular suite (it writes files):
//
//   flutter test tool/screenshots/render_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/app/app.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/dev/demo_seed.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/helpers/test_db.dart';

/// The test binding replaces every font with a blocky placeholder; load the
/// real ones from the SDK cache so screenshots look like the shipped app.
Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('$dir/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(_loadRealFonts);

  testWidgets('render README screenshots', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Pixel-ish phone: 1080x2400 @ 2.625.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;

    // This IS a test — it just lives outside test/ so the CI suite skips it.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = createTestDatabase();
    final clock = FixedClock(DateTime(2026, 7, 15, 10, 30));
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(clock.call),
      ],
    );
    // Under fake async drift's zero-delay timers never fire without pumping;
    // runAsync gives the seeder a real event loop.
    await tester.runAsync(() => seedDemoInto(container));

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: rootKey,
        child: UncontrolledProviderScope(
          container: container,
          child: const GutJourneyApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.625);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('docs/screenshots/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      debugPrint('wrote docs/screenshots/$name.png');
    }

    await capture('today');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await capture('history');

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    // The 7-day window is the densest with a 10-day dataset.
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    await capture('stats');

    // Unmount and deliberately LEAK the database: after runAsync drift's
    // teardown timers straddle the fake and real event loops and close()
    // deadlocks. This is a one-shot tool process — the OS reclaims it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
}
