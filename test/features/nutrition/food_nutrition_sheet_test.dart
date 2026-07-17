import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food library'));
    await tester.pumpAndSettle();
  }

  testApp('saving the sheet stores nutrition attribute rows', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await openLibrary(tester);
    await tester.tap(find.byTooltip('Nutrition values'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'kcal per serving'),
      '220',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Protein'), '4.5');
    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.source == nutritionAttributeSource), isTrue);
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey[nutritionKcalKey], '220.0');
    expect(byKey[nutritionProteinKey], '4.5');

    // The library tile now advertises the estimate.
    expect(find.textContaining('220 kcal/serving'), findsOneWidget);
  });

  testApp('reopening prefills and clearing a field removes its row', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final rice = await foods.create('Rice');
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionKcalKey,
      value: '220.0',
    );
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionProteinKey,
      value: '4.5',
    );

    await openLibrary(tester);
    await tester.tap(find.byTooltip('Nutrition values'));
    await tester.pumpAndSettle();

    // Prefilled without the trailing .0 for whole numbers.
    expect(find.widgetWithText(TextField, '220'), findsOneWidget);
    expect(find.widgetWithText(TextField, '4.5'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '220'), '');
    // Unfocus so the scroll view stops chasing the caret at the top and
    // the Save button can be scrolled into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey.containsKey(nutritionKcalKey), isFalse);
    expect(byKey[nutritionProteinKey], '4.5');
  });
}
