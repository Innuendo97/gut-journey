import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';

import '../../helpers/pump_app.dart';

/// Three milk lunches each followed by bloating 6h later (inside the 8h
/// window, outside the 4h one) and three symptom-free rice lunches.
Future<void> seedPattern(TestHarness harness) async {
  final meals = MealRepository(
    harness.db,
    FoodRepository(harness.db, harness.clock.call),
    harness.clock.call,
  );
  final symptoms = SymptomRepository(harness.db, harness.clock.call);
  for (final day in [8, 9, 10]) {
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, day, 13),
      items: const [MealItemInput.newFood(name: 'Milk')],
    );
    await symptoms.addEntry(
      symptomTypeId: symptomPresetId('bloating'),
      intensity: 6,
      occurredAt: DateTime(2026, 7, day, 19),
    );
  }
  for (final day in [11, 12, 13]) {
    await meals.createMeal(
      type: MealType.lunch,
      occurredAt: DateTime(2026, 7, day, 13),
      items: const [MealItemInput.newFood(name: 'Rice')],
    );
  }
}

void main() {
  testApp('stats card shows an empty hint and links to the screen', (
    tester,
    harness,
  ) async {
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Observed patterns'), findsOneWidget);
    expect(
      find.text(
        'Log meals and symptoms for a couple of weeks to see observed '
        'patterns here.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('No patterns to show yet'), findsOneWidget);
    expect(find.text('How this works'), findsOneWidget);
  });

  testApp('a seeded pattern reaches the card and the ranked list', (
    tester,
    harness,
  ) async {
    await seedPattern(harness);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    // Card teaser with the strength chip and the observational disclaimer.
    expect(find.text('Bloating after Milk'), findsOneWidget);
    expect(find.text('Strong signal'), findsOneWidget);
    expect(
      find.text(
        'These are observed patterns in your diary, not causes. '
        'Discuss them with your doctor.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Observed patterns'));
    await tester.pumpAndSettle();

    expect(find.text('After meals with Milk: 3 of 3'), findsOneWidget);
    expect(find.text('After meals without it: 0 of 3'), findsOneWidget);
    expect(
      find.text('Never observed after meals without it in this period'),
      findsOneWidget,
    );
    expect(
      find.text('6 meals and 3 symptom entries analyzed'),
      findsOneWidget,
    );
  });

  testApp('narrowing the window drops the pattern honestly', (
    tester,
    harness,
  ) async {
    await seedPattern(harness);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Observed patterns'));
    await tester.pumpAndSettle();

    expect(find.text('Strong signal'), findsOneWidget);

    await tester.tap(find.text('4 h'));
    await tester.pumpAndSettle();

    expect(find.text('Strong signal'), findsNothing);
    expect(
      find.text(
        'No clear patterns in this period — that is useful information too.',
      ),
      findsOneWidget,
    );
    // The method explanation follows the selected window.
    expect(find.textContaining('within 4 hours'), findsOneWidget);
  });
}
