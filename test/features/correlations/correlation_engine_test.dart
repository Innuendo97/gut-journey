import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/correlations/domain/correlation_engine.dart';
import 'package:gut_journey/features/correlations/domain/correlation_models.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';

void main() {
  const engine = CorrelationEngine();
  const window = Duration(hours: 8);

  DateTime at(int day, [int hour = 12, int minute = 0]) =>
      DateTime(2026, 7, day, hour, minute);

  MealEntry meal(DateTime occurredAt, List<String> foods) => MealEntry(
    id: 'meal-$occurredAt',
    type: MealType.lunch,
    occurredAt: occurredAt,
    day: LocalDay.fromDateTime(occurredAt),
    items: [
      for (final name in foods)
        MealItem(
          food: FoodItem(id: 'food-$name', name: name),
        ),
    ],
  );

  SymptomEntry event(DateTime occurredAt, {String type = 'bloating'}) =>
      SymptomEntry(
        id: 'sym-$type-$occurredAt',
        symptomTypeId: type,
        intensity: 5,
        occurredAt: occurredAt,
        day: LocalDay.fromDateTime(occurredAt),
      );

  List<FoodSymptomAssociation> forFood(
    CorrelationsResult result,
    String name,
  ) => [
    for (final a in result.associations)
      if (a.foodName == name) a,
  ];

  // One meal per day at noon: 4 with milk, 6 without; the symptom follows
  // 2 of the milk meals and 1 baseline meal.
  List<MealEntry> tenMeals() => [
    for (var d = 1; d <= 4; d++) meal(at(d), ['Milk']),
    for (var d = 5; d <= 10; d++) meal(at(d), ['Rice']),
  ];

  test('computes rates, lift and adjusted lift on a hand-checked case', () {
    final result = engine.compute(
      meals: tenMeals(),
      symptoms: [event(at(1, 14)), event(at(2, 14)), event(at(5, 14))],
      window: window,
    );

    expect(result.analyzedMeals, 10);
    expect(result.analyzedSymptomEvents, 3);
    final milk = forFood(result, 'Milk').single;
    expect(milk.symptomTypeId, 'bloating');
    expect(milk.exposedMeals, 4);
    expect(milk.exposedWithSymptom, 2);
    expect(milk.baselineMeals, 6);
    expect(milk.baselineWithSymptom, 1);
    expect(milk.exposedRate, closeTo(0.5, 1e-9));
    expect(milk.baselineRate, closeTo(1 / 6, 1e-9));
    expect(milk.lift, closeTo(3.0, 1e-9));
    // ((2 + 0.5) / (4 + 1)) / ((1 + 0.5) / (6 + 1)) = 0.5 / (1.5 / 7)
    expect(milk.adjustedLift, closeTo(7 / 3, 1e-9));
    expect(milk.strength, CorrelationStrength.moderate);
  });

  test('window is (mealAt, mealAt + window]: start excluded, end included', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [
        event(at(1)), // exactly at the meal moment → excluded
        event(at(2, 20)), // exactly at mealAt + 8h → included
        event(at(3, 14)),
      ],
      window: window,
    );

    expect(forFood(result, 'Milk').single.exposedWithSymptom, 2);
  });

  test('several events in one window count once per meal', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [
        event(at(1, 13)),
        event(at(1, 14)),
        event(at(1, 15)),
        event(at(2, 13)),
      ],
      window: window,
    );

    expect(forFood(result, 'Milk').single.exposedWithSymptom, 2);
  });

  test('the same food twice in a meal is one exposure', () {
    final result = engine.compute(
      meals: [
        meal(at(1), ['Milk', 'Milk']),
        meal(at(2), ['Milk']),
        meal(at(3), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [event(at(1, 13)), event(at(2, 13)), event(at(5, 13))],
      window: window,
    );

    expect(forFood(result, 'Milk').single.exposedMeals, 3);
  });

  test('zero baseline hits: lift is null, adjusted lift stays finite', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [event(at(1, 13)), event(at(2, 13)), event(at(3, 13))],
      window: window,
    );

    final milk = forFood(result, 'Milk').single;
    expect(milk.baselineWithSymptom, 0);
    expect(milk.lift, isNull);
    // ((3 + 0.5) / (3 + 1)) / ((0 + 0.5) / (3 + 1)) = 0.875 / 0.125
    expect(milk.adjustedLift, closeTo(7.0, 1e-9));
    expect(milk.strength, CorrelationStrength.strong);
  });

  test('foods below the exposure or baseline minimums are not reported', () {
    // Bread: 2 exposures (< 3). Rice: in 7 of 9 meals → baseline 2 (< 3).
    final result = engine.compute(
      meals: [
        meal(at(1), ['Bread', 'Rice']),
        meal(at(2), ['Bread', 'Rice']),
        for (var d = 3; d <= 7; d++) meal(at(d), ['Rice']),
        meal(at(8), ['Egg']),
        meal(at(9), ['Egg']),
      ],
      symptoms: [event(at(1, 13)), event(at(2, 13)), event(at(3, 13))],
      window: window,
    );

    expect(forFood(result, 'Bread'), isEmpty);
    expect(forFood(result, 'Rice'), isEmpty);
  });

  test('a single co-occurrence is not reported', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [
        event(at(1, 13)),
        // Same type but outside every meal window: keeps the type eligible
        // without adding co-occurrences.
        event(at(1, 6)),
        event(at(2, 6)),
      ],
      window: window,
    );

    expect(result.associations, isEmpty);
  });

  test('a symptom type with too few events is not analyzed', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [event(at(1, 13)), event(at(2, 13))],
      window: window,
    );

    expect(result.associations, isEmpty);
  });

  test('no positive signal when the baseline rate is higher', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [
        event(at(1, 13)),
        event(at(2, 13)),
        event(at(4, 13)),
        event(at(5, 13)),
        event(at(6, 13)),
      ],
      window: window,
    );

    // Milk 2/3 vs baseline 3/3; Rice 3/3 vs 2/3 is positive but that is the
    // whole point: only Rice may be reported, never Milk.
    expect(forFood(result, 'Milk'), isEmpty);
  });

  test('meals without items are excluded from the analysis entirely', () {
    final result = engine.compute(
      meals: [
        meal(at(1, 9), const []), // unknown composition
        meal(at(2, 9), const []),
        ...tenMeals(),
      ],
      symptoms: [event(at(1, 14)), event(at(2, 14)), event(at(5, 14))],
      window: window,
    );

    expect(result.analyzedMeals, 10);
    final milk = forFood(result, 'Milk').single;
    expect(milk.baselineMeals, 6);
  });

  test('ranks by strength, then adjusted lift', () {
    final result = engine.compute(
      meals: [
        for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
        for (var d = 4; d <= 6; d++) meal(at(d), ['Wheat']),
        for (var d = 7; d <= 12; d++) meal(at(d), ['Rice']),
      ],
      symptoms: [
        event(at(1, 13)),
        event(at(2, 13)),
        event(at(3, 13)),
        event(at(4, 13)),
        event(at(5, 13)),
        event(at(7, 13)),
      ],
      window: window,
    );

    // Milk 3/3 vs 3/9 → adjusted 2.5 (strong); Wheat 2/3 vs 4/9 → ≈1.39
    // (weak).
    expect(result.associations.map((a) => a.foodName), ['Milk', 'Wheat']);
    expect(result.associations.first.strength, CorrelationStrength.strong);
    expect(result.associations.last.strength, CorrelationStrength.weak);
  });

  test('an event 6h after the meal counts at 8h and 24h, not at 4h', () {
    final meals = [
      for (var d = 1; d <= 3; d++) meal(at(d), ['Milk']),
      for (var d = 4; d <= 6; d++) meal(at(d), ['Rice']),
    ];
    final symptoms = [event(at(1, 18)), event(at(2, 18)), event(at(3, 18))];

    for (final (hours, reported) in [(4, 0), (8, 1), (24, 1)]) {
      final result = engine.compute(
        meals: meals,
        symptoms: symptoms,
        window: Duration(hours: hours),
      );
      expect(
        result.associations,
        hasLength(reported),
        reason: 'window ${hours}h',
      );
    }
  });

  test('the same raw ratio earns a higher bucket with more data', () {
    // 20/40 vs 10/60 — the same 3.0 raw lift as the hand-checked 2/4 vs 1/6
    // case, which lands on moderate; more data → strong.
    final result = engine.compute(
      meals: [
        for (var d = 0; d < 40; d++)
          meal(DateTime(2026, 1, 1 + d, 12), ['Milk']),
        // Day overflow past March 31 rolls into April.
        for (var d = 0; d < 60; d++)
          meal(DateTime(2026, 3, 1 + d, 12), ['Rice']),
      ],
      symptoms: [
        for (var d = 0; d < 20; d++) event(DateTime(2026, 1, 1 + d, 14)),
        for (var d = 0; d < 10; d++) event(DateTime(2026, 3, 1 + d, 14)),
      ],
      window: window,
    );

    final milk = forFood(result, 'Milk').single;
    expect(milk.lift, closeTo(3.0, 1e-9));
    // ((20 + 0.5) / 41) / ((10 + 0.5) / 61) = 0.5 / (10.5 / 61) ≈ 2.905
    expect(milk.adjustedLift, closeTo(0.5 / (10.5 / 61), 1e-9));
    expect(milk.strength, CorrelationStrength.strong);
  });
}
