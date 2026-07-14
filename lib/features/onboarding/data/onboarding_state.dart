import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';

/// Whether the user has explicitly accepted the medical disclaimer. The app
/// is gated behind this: the router redirects to onboarding until accepted.
final onboardingAcceptedProvider =
    NotifierProvider<OnboardingAcceptedNotifier, bool>(
      OnboardingAcceptedNotifier.new,
    );

class OnboardingAcceptedNotifier extends Notifier<bool> {
  static const _key = 'onboarding_accepted';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> accept() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}
