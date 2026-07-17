import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';

import '../../helpers/pump_app.dart';

const _fixture = '''
{"version": 1, "foods": [
  {"id": "pasta-semola-cruda", "it": "Pasta di semola (cruda)",
   "en": "Durum wheat pasta (dry)", "cat": "cereali-pasta",
   "per100g": {"kcal": 353, "protein": 10.9, "carbs": 79.1, "fat": 1.4, "fiber": 2.7},
   "serving": {"g": 80, "it": "una porzione (80 g)", "en": "one serving (80 g)"}}
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
  Future<void> openAddFood(WidgetTester tester) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add food'));
    await tester.pumpAndSettle();
  }

  testApp(
    'searching the registry and importing a match fills the library',
    overrides: [_registryOverride],
    (tester, harness) async {
      await openAddFood(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search the food registry'),
        'pasta',
      );
      await tester.pumpAndSettle();

      // Match with kcal + category subtitle.
      expect(find.textContaining('353 kcal/100g'), findsOneWidget);
      await tester.tap(find.text('Durum wheat pasta (dry)'));
      await tester.pumpAndSettle();

      // Sheet closed, confirmation shown, library row present with values.
      expect(
        find.textContaining('added to your library'),
        findsOneWidget,
      );
      expect(find.text('Durum wheat pasta (dry)'), findsOneWidget);
      final attributes = await harness.db
          .select(harness.db.foodAttributes)
          .get();
      final byKey = {for (final r in attributes) r.key: r.value};
      expect(byKey['kcal_per_100g'], '353.0');
      expect(byKey['serving_g'], '80.0');
    },
  );

  testApp(
    'creating a custom food opens its nutrition editor directly',
    overrides: [_registryOverride],
    (tester, harness) async {
      await openAddFood(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search the food registry'),
        'Grandma broth',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create "Grandma broth"'));
      await tester.pumpAndSettle();

      // The nutrition editor opened for the new food.
      expect(find.text('kcal per 100 g'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'kcal per 100 g'),
        '55',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tapInSheet(tester, 'Save');

      final foods = await harness.db.select(harness.db.foodItems).get();
      expect(foods.single.name, 'Grandma broth');
      final attributes = await harness.db
          .select(harness.db.foodAttributes)
          .get();
      expect(attributes.single.value, '55.0');
    },
  );
}
