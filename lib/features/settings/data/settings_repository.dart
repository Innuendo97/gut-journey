import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main` with the real instance (and in tests with a mock),
/// so settings reads stay synchronous everywhere else.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'Override sharedPreferencesProvider before running the app',
  ),
);

/// App preferences. Diary data lives in the database; this is only
/// device-local configuration.
class AppSettings {
  const AppSettings({required this.waterGoalMl});

  final int waterGoalMl;

  static const defaultWaterGoalMl = 2000;

  AppSettings copyWith({int? waterGoalMl}) =>
      AppSettings(waterGoalMl: waterGoalMl ?? this.waterGoalMl);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _waterGoalKey = 'water_goal_ml';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      waterGoalMl:
          prefs.getInt(_waterGoalKey) ?? AppSettings.defaultWaterGoalMl,
    );
  }

  Future<void> setWaterGoalMl(int goal) async {
    state = state.copyWith(waterGoalMl: goal);
    await ref.read(sharedPreferencesProvider).setInt(_waterGoalKey, goal);
  }
}
