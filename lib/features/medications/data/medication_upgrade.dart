import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';

/// Preference flag marking the one-time window backfill as done.
const medicationWindowsClosedKey = 'medication_windows_closed';

/// Runs [MedicationRepository.closeOrphanEndDays] once on the first launch
/// after day-window semantics landed (v0.6), then never again. Watched at
/// startup; nothing waits on it.
final medicationUpgradeProvider = FutureProvider<void>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (prefs.getBool(medicationWindowsClosedKey) ?? false) return;
  await ref.read(medicationRepositoryProvider).closeOrphanEndDays();
  await prefs.setBool(medicationWindowsClosedKey, true);
});
