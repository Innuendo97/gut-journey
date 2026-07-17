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

  testApp('saving the sheet stores per-100g attribute rows', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    await foods.create('Rice');

    await openLibrary(tester);
    await tester.tap(find.byTooltip('Nutrition values'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'kcal per 100 g'),
      '130',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Protein'), '2.7');
    await tester.enterText(
      find.widgetWithText(TextField, 'Typical serving weight'),
      '150',
    );
    await tester.pump();
    // The live preview reflects the typed base and serving weight.
    expect(find.text('1 serving (150 g) ≈ 195 kcal'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    expect(rows, hasLength(3));
    expect(rows.every((r) => r.source == nutritionAttributeSource), isTrue);
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey[nutritionKcal100Key], '130.0');
    expect(byKey[nutritionProtein100Key], '2.7');
    expect(byKey[nutritionServingGKey], '150.0');

    // The library tile now advertises the estimate on the per-100g base.
    expect(find.textContaining('130 kcal/100g'), findsOneWidget);
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
      key: nutritionKcal100Key,
      value: '130.0',
    );
    await foods.setAttribute(
      foodItemId: rice.id,
      source: nutritionAttributeSource,
      key: nutritionProtein100Key,
      value: '2.7',
    );

    await openLibrary(tester);
    await tester.tap(find.byTooltip('Nutrition values'));
    await tester.pumpAndSettle();

    // Prefilled without the trailing .0 for whole numbers.
    expect(find.widgetWithText(TextField, '130'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2.7'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '130'), '');
    // Unfocus so the scroll view stops chasing the caret at the top and
    // the Save button can be scrolled into view.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey.containsKey(nutritionKcal100Key), isFalse);
    expect(byKey[nutritionProtein100Key], '2.7');
  });

  testApp('legacy per-serving values convert to per-100g on request', (
    tester,
    harness,
  ) async {
    final foods = FoodRepository(harness.db, harness.clock.call);
    final pasta = await foods.create('Pasta');
    await foods.setAttribute(
      foodItemId: pasta.id,
      source: nutritionAttributeSource,
      key: nutritionKcalKey,
      value: '282.0',
    );
    await foods.setAttribute(
      foodItemId: pasta.id,
      source: nutritionAttributeSource,
      key: nutritionProteinKey,
      value: '8.7',
    );

    await openLibrary(tester);
    await tester.tap(find.byTooltip('Nutrition values'));
    await tester.pumpAndSettle();

    // The banner announces the legacy values; converting needs a weight.
    expect(
      find.textContaining('Per-serving values detected'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Typical serving weight'),
      '80',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tapInSheet(tester, 'Convert');

    // 282 ÷ 80 × 100 = 352.5; 8.7 ÷ 80 × 100 = 10.9 (one decimal).
    expect(find.widgetWithText(TextField, '352.5'), findsOneWidget);
    expect(find.widgetWithText(TextField, '10.9'), findsOneWidget);

    await tapInSheet(tester, 'Save');

    final rows = await harness.db.select(harness.db.foodAttributes).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey[nutritionKcal100Key], '352.5');
    expect(byKey[nutritionProtein100Key], '10.9');
    expect(byKey[nutritionServingGKey], '80.0');
    // Legacy rows survive — historical meal rows still compute from them.
    expect(byKey[nutritionKcalKey], '282.0');
    expect(byKey[nutritionProteinKey], '8.7');
  });
}
