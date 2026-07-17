import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/app_shell.dart';
import 'package:gut_journey/features/correlations/presentation/correlations_screen.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_foods_screen.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_screen.dart';
import 'package:gut_journey/features/history/presentation/history_screen.dart';
import 'package:gut_journey/features/meals/presentation/food_library_screen.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/presentation/medication_form_screen.dart';
import 'package:gut_journey/features/medications/presentation/medications_screen.dart';
import 'package:gut_journey/features/onboarding/data/onboarding_state.dart';
import 'package:gut_journey/features/onboarding/presentation/onboarding_screen.dart';
import 'package:gut_journey/features/settings/presentation/more_screen.dart';
import 'package:gut_journey/features/settings/presentation/settings_screen.dart';
import 'package:gut_journey/features/stats/presentation/stats_screen.dart';
import 'package:gut_journey/features/symptoms/presentation/symptom_types_screen.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const history = '/history';
  static const stats = '/stats';
  static const statsCorrelations = '/stats/correlations';
  static const more = '/more';
  static const moreFoods = '/more/foods';
  static const moreFodmap = '/more/fodmap';
  static const moreFodmapFoods = '/more/fodmap/foods';
  static const moreMedications = '/more/medications';
  static const moreMedicationsNew = '/more/medications/new';
  static const moreSettings = '/more/settings';
  static const moreSettingsSymptoms = '/more/settings/symptoms';

  static String moreMedicationEdit(String id) => '/more/medications/$id/edit';
}

final routerProvider = Provider<GoRouter>((ref) {
  final onboardingAccepted = ref.watch(onboardingAcceptedProvider);
  return GoRouter(
    initialLocation: AppRoutes.today,
    // The diary is gated behind the explicit disclaimer acceptance.
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboardingAccepted && !atOnboarding) return AppRoutes.onboarding;
      if (onboardingAccepted && atOnboarding) return AppRoutes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatsScreen(),
                routes: [
                  GoRoute(
                    path: 'correlations',
                    builder: (context, state) => const CorrelationsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'foods',
                    builder: (context, state) => const FoodLibraryScreen(),
                  ),
                  GoRoute(
                    path: 'fodmap',
                    builder: (context, state) => const FodmapScreen(),
                    routes: [
                      GoRoute(
                        path: 'foods',
                        builder: (context, state) => const FodmapFoodsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'medications',
                    builder: (context, state) => const MedicationsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const MedicationFormScreen(),
                      ),
                      GoRoute(
                        path: ':id/edit',
                        builder: (context, state) => MedicationFormScreen(
                          existing: state.extra as Medication?,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'symptoms',
                        builder: (context, state) => const SymptomTypesScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
