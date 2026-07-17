import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';

/// Preference flag marking the one-time per-100g upgrade as done.
const nutritionPer100MigratedKey = 'nutrition_per100_migrated';

/// Runs [FoodRegistryRepository.upgradeImportedFoods] once on the first
/// launch after the per-100g model landed (v0.5), then never again. The
/// app watches this at startup; nothing waits on it — the diary works
/// while (and even if) the upgrade runs.
final registryUpgradeProvider = FutureProvider<void>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs.getBool(nutritionPer100MigratedKey) ?? false) return;
  await ref.read(foodRegistryRepositoryProvider).upgradeImportedFoods();
  await prefs.setBool(nutritionPer100MigratedKey, true);
});
