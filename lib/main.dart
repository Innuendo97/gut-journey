import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/app/app.dart';
import 'package:gut_journey/dev/demo_seed.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Screenshot/demo tooling; the const condition compiles out of release.
  if (demoSeedRequested && !kReleaseMode) {
    await seedDemoData(prefs);
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GutJourneyApp(),
    ),
  );
}
