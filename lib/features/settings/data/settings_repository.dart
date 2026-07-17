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
  const AppSettings({
    required this.waterGoalMl,
    this.kcalGoal = defaultKcalGoal,
    this.localeTag,
  });

  final int waterGoalMl;

  /// Optional daily energy goal in kcal; 0 means off. Off by default so the
  /// app never volunteers a target — estimates only, discussed with the
  /// user's clinician.
  final int kcalGoal;

  /// BCP-47 tag ('en', 'it') of the forced app language, or null to follow
  /// the system locale.
  final String? localeTag;

  static const defaultWaterGoalMl = 2000;
  static const defaultKcalGoal = 0;

  AppSettings copyWith({
    int? waterGoalMl,
    int? kcalGoal,
    String? Function()? localeTag,
  }) => AppSettings(
    waterGoalMl: waterGoalMl ?? this.waterGoalMl,
    kcalGoal: kcalGoal ?? this.kcalGoal,
    localeTag: localeTag != null ? localeTag() : this.localeTag,
  );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _waterGoalKey = 'water_goal_ml';
  static const _kcalGoalKey = 'kcal_goal';
  static const _localeKey = 'locale_tag';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      waterGoalMl:
          prefs.getInt(_waterGoalKey) ?? AppSettings.defaultWaterGoalMl,
      kcalGoal: prefs.getInt(_kcalGoalKey) ?? AppSettings.defaultKcalGoal,
      localeTag: prefs.getString(_localeKey),
    );
  }

  Future<void> setWaterGoalMl(int goal) async {
    state = state.copyWith(waterGoalMl: goal);
    await ref.read(sharedPreferencesProvider).setInt(_waterGoalKey, goal);
  }

  /// 0 turns the goal off.
  Future<void> setKcalGoal(int goal) async {
    state = state.copyWith(kcalGoal: goal);
    await ref.read(sharedPreferencesProvider).setInt(_kcalGoalKey, goal);
  }

  /// Pass null to follow the system locale.
  Future<void> setLocaleTag(String? tag) async {
    state = state.copyWith(localeTag: () => tag);
    final prefs = ref.read(sharedPreferencesProvider);
    if (tag == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, tag);
    }
  }
}
