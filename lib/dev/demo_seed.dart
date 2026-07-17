import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/providers/database_provider.dart';
import 'package:gut_journey/features/activity/data/activity_repository.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';
import 'package:gut_journey/features/bowel/data/bowel_repository.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/onboarding/data/onboarding_state.dart';
import 'package:gut_journey/features/settings/data/settings_repository.dart';
import 'package:gut_journey/features/sleep/data/sleep_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_presets.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time switch for screenshot/demo builds:
/// `flutter build apk --debug --dart-define=DEMO_SEED=true`.
/// Const, so release builds tree-shake the whole seeder out.
const demoSeedRequested = bool.fromEnvironment('DEMO_SEED');

const _breakfasts = [
  ['Oat porridge', 'Blueberries'],
  ['Eggs', 'Gluten-free toast'],
  ['Lactose-free yogurt', 'Granola'],
];
const _lunches = [
  ['Grilled chicken', 'Rice', 'Zucchini'],
  ['Salmon', 'Potatoes', 'Green beans'],
  ['Rice noodles', 'Tofu', 'Carrots'],
];
const _dinners = [
  ['Turkey', 'Quinoa', 'Spinach'],
  ['White fish', 'Rice', 'Tomatoes'],
  ['Chicken soup', 'Sourdough bread'],
];
const _activities = [
  ('Walking', 35, Effort.light),
  ('Yoga', 25, Effort.light),
  ('Swimming', 40, Effort.moderate),
  ('Cycling', 45, Effort.moderate),
];

/// Plausible per-100g profiles (kcal/100g, typical serving in grams) for
/// part of the demo library, so the Today card, the Stats energy chart and
/// the meal sheet's live kcal have data in screenshots. Deliberately not
/// all foods: partial tracking is the realistic state.
const _foodProfiles = <String, (int, int)>{
  'Oat porridge': (88, 250),
  'Eggs': (155, 100),
  'Rice': (130, 150),
  'Grilled chicken': (165, 140),
  'Salmon': (208, 150),
  'Potatoes': (87, 200),
  'Quinoa': (120, 160),
  'Rice noodles': (108, 180),
};

/// Fills ~10 days of realistic diary data through the real repositories the
/// first time a DEMO_SEED build launches (no-op when data exists), and
/// accepts onboarding so screenshot runs land straight on Today.
///
/// Deterministic on purpose — index-derived variety, no randomness — so
/// screenshots are reproducible. Food and activity names are data, not UI
/// copy, hence not localized.
Future<void> seedDemoData(SharedPreferences prefs) async {
  // A short-lived container of its own: disposed (closing its database
  // connection) before the app's container opens the same file.
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  try {
    await seedDemoInto(container);
  } finally {
    container.dispose();
  }
}

/// The seeding itself, against whatever database/clock [container] resolves —
/// reused by the screenshot tool with an in-memory database.
Future<void> seedDemoInto(ProviderContainer container) async {
  final db = container.read(databaseProvider);
  final existing = await (db.select(db.mealEntries)..limit(1)).get();
  if (existing.isNotEmpty) return;

  await container.read(onboardingAcceptedProvider.notifier).accept();

  final meals = container.read(mealRepositoryProvider);
  final symptoms = container.read(symptomRepositoryProvider);
  final bowel = container.read(bowelRepositoryProvider);
  final weight = container.read(weightRepositoryProvider);
  final water = container.read(waterRepositoryProvider);
  final sleep = container.read(sleepRepositoryProvider);
  final activity = container.read(activityRepositoryProvider);
  final medications = container.read(medicationRepositoryProvider);

  final today = LocalDay.fromDateTime(container.read(clockProvider)());
  final medicationId = await medications.createMedication(
    name: 'Probiotic',
    scheduleType: ScheduleType.daily,
    scheduledTimes: const ['08:00'],
    startDay: today.addDays(-9),
  );

  Future<void> addMeal(
    LocalDay day,
    MealType type,
    int hour,
    List<String> foods,
  ) => meals.createMeal(
    type: type,
    occurredAt: day.toDateTime().add(Duration(hours: hour)),
    items: [
      for (final food in foods)
        // Profiled foods log their typical amount in grams; the rest stay
        // amountless, like a hurried real entry.
        MealItemInput.newFood(
          name: food,
          amountG: _foodProfiles[food]?.$2.toDouble(),
        ),
    ],
  );

  for (var i = 9; i >= 0; i--) {
    final day = today.addDays(-i);
    DateTime at(int hour, [int minute = 0]) =>
        day.toDateTime().add(Duration(hours: hour, minutes: minute));

    await addMeal(day, MealType.breakfast, 8, _breakfasts[i % 3]);
    await addMeal(day, MealType.lunch, 13, _lunches[(i + 1) % 3]);
    await addMeal(day, MealType.dinner, 20, _dinners[(i + 2) % 3]);
    if (i % 3 == 0) {
      await addMeal(day, MealType.snack, 17, const ['Banana']);
    }

    for (var glass = 0; glass < 3 + (i % 3); glass++) {
      await water.add(
        amountMl: glass.isEven ? 250 : 330,
        occurredAt: at(9 + glass * 3),
      );
    }

    // A recurring main symptom plus an occasional second one, so the
    // stats charts show real trends instead of one-off points.
    if (i != 2 && i != 6) {
      await symptoms.addEntry(
        symptomTypeId: symptomPresetId('bloating'),
        intensity: 2 + ((i * 3) % 5),
        occurredAt: at(15, 30),
        durationMinutes: 30 + (i % 3) * 15,
      );
    }
    if (i % 3 == 1) {
      await symptoms.addEntry(
        symptomTypeId: symptomPresetId('abdominal_pain'),
        intensity: 3 + (i % 3),
        occurredAt: at(21, 10),
      );
    }

    await bowel.add(
      bristolType: 3 + (i % 3),
      occurredAt: at(7, 40),
      urgency: i == 4,
    );

    if (i.isEven) {
      await weight.add(weightKg: 70.9 + i * 0.1, occurredAt: at(7, 30));
    }

    await sleep.upsertForDay(
      day: day,
      durationMinutes: 410 + (i % 4) * 25,
      quality: 3 + (i % 3),
    );

    if (i.isOdd || i % 3 == 0) {
      final (name, minutes, effort) = _activities[i % _activities.length];
      await activity.add(
        name: name,
        durationMinutes: minutes,
        effort: effort,
        occurredAt: at(18, 15),
      );
    }

    if (i != 3) {
      await medications.logIntake(
        medicationId: medicationId,
        status: IntakeStatus.taken,
        occurredAt: at(8, 5),
        scheduledTime: '08:00',
      );
    }
  }

  // Nutrition estimates on the foods the meals above created.
  final foods = container.read(foodRepositoryProvider);
  for (final MapEntry(key: name, value: (kcal100, servingG))
      in _foodProfiles.entries) {
    final item = await foods.getOrCreateByName(name);
    await foods.setAttribute(
      foodItemId: item.id,
      source: nutritionAttributeSource,
      key: nutritionKcal100Key,
      value: '$kcal100',
    );
    await foods.setAttribute(
      foodItemId: item.id,
      source: nutritionAttributeSource,
      key: nutritionServingGKey,
      value: '$servingG',
    );
  }
  // One food stays on the legacy per-serving base — the realistic mixed
  // state after the v0.5 upgrade.
  final banana = await foods.getOrCreateByName('Banana');
  await foods.setAttribute(
    foodItemId: banana.id,
    source: nutritionAttributeSource,
    key: nutritionKcalKey,
    value: '90',
  );
}
