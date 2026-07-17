import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';

import '../../helpers/pump_app.dart';

const _fixture = '''
{"version": 1, "foods": [
  {"id": "mozzarella-di-bufala", "it": "Mozzarella di bufala",
   "en": "Buffalo mozzarella", "cat": "latticini",
   "per100g": {"kcal": 288, "protein": 16.7, "carbs": 0.4, "fat": 24.4, "fiber": 0},
   "serving": {"g": 125, "it": "una mozzarella (125 g)", "en": "one ball (125 g)"}}
]}
''';

final _registryOverride = foodRegistryRepositoryProvider.overrideWith(
  (ref) => FoodRegistryRepository(
    ref.watch(foodRepositoryProvider),
    ref.watch(nutritionRepositoryProvider),
    loadAsset: () async => _fixture,
  ),
);

void main() {
  testApp(
    'a registry suggestion imports the food with its values on tap',
    overrides: [_registryOverride],
    (tester, harness) async {
      await tapQuickAdd(tester, 'Meal');
      await tester.enterText(find.byType(TextField).first, 'mozza');
      await tester.pumpAndSettle();

      // The registry chip is visually distinct (book icon) and shows the
      // localized name (test locale is English).
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      await tapInSheet(tester, 'Buffalo mozzarella');

      // Imported into the library with per-serving values and provenance.
      final attributes = await harness.db
          .select(harness.db.foodAttributes)
          .get();
      final byKey = {for (final r in attributes) r.key: r.value};
      expect(byKey['kcal_per_serving'], '360.0'); // 288 × 1.25
      expect(byKey['origin'], 'registry:mozzarella-di-bufala@v1');

      await tapInSheet(tester, 'Save');

      // The day total picks the estimate up immediately...
      expect(find.text('Energy (estimated)'), findsOneWidget);
      expect(find.text('360 kcal'), findsOneWidget);
      // ...and no "add values" nudge fires: the food came with values.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('no nutrition values'), findsNothing);
    },
  );

  testApp(
    'an imported registry food shows as a personal suggestion next time',
    overrides: [_registryOverride],
    (tester, harness) async {
      await tapQuickAdd(tester, 'Meal');
      await tester.enterText(find.byType(TextField).first, 'mozza');
      await tester.pumpAndSettle();
      await tapInSheet(tester, 'Buffalo mozzarella');
      await tapInSheet(tester, 'Save');

      await tapQuickAdd(tester, 'Meal');
      await tester.enterText(find.byType(TextField).first, 'Buffalo');
      await tester.pumpAndSettle();

      // Only the personal chip now — the registry twin hides behind it.
      expect(
        find.widgetWithText(ActionChip, 'Buffalo mozzarella'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    },
  );
}
