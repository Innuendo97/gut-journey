import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/app_shell.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/features/history/presentation/history_screen.dart';
import 'package:gut_journey/features/meals/presentation/food_library_screen.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/presentation/medication_form_screen.dart';
import 'package:gut_journey/features/medications/presentation/medications_screen.dart';
import 'package:gut_journey/features/settings/presentation/more_screen.dart';
import 'package:gut_journey/features/stats/presentation/stats_screen.dart';

abstract final class AppRoutes {
  static const today = '/today';
  static const history = '/history';
  static const stats = '/stats';
  static const more = '/more';
  static const moreFoods = '/more/foods';
  static const moreMedications = '/more/medications';
  static const moreMedicationsNew = '/more/medications/new';

  static String moreMedicationEdit(String id) => '/more/medications/$id/edit';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.today,
    routes: [
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
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
