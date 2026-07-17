import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/db/app_database.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';

import '../../helpers/test_db.dart';

const _fixture = '''
{"version": 1, "foods": [
  {"id": "pasta-semola-cruda", "it": "Pasta di semola (cruda)",
   "en": "Durum wheat pasta (dry)", "cat": "cereali-pasta",
   "per100g": {"kcal": 353, "protein": 10.9, "carbs": 79.1, "fat": 1.4, "fiber": 2.7},
   "serving": {"g": 80, "it": "una porzione (80 g)", "en": "one serving (80 g)"}},
  {"id": "mozzarella-di-bufala", "it": "Mozzarella di bufala",
   "en": "Buffalo mozzarella", "cat": "latticini",
   "per100g": {"kcal": 288, "protein": 16.7, "carbs": 0.4, "fat": 24.4, "fiber": 0},
   "serving": {"g": 125, "it": "una mozzarella (125 g)", "en": "one ball (125 g)"}},
  {"id": "vino-rosso", "it": "Vino rosso (100 ml)", "en": "Red wine (100 ml)",
   "cat": "bevande",
   "per100g": {"kcal": 76, "protein": 0.1, "carbs": 0.2, "fat": 0, "fiber": 0, "alcohol": 10.5},
   "serving": {"g": 125, "it": "un bicchiere (125 ml)", "en": "one glass (125 ml)"}}
]}
''';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FoodRepository foods;
  late NutritionRepository nutrition;
  late FoodRegistryRepository repo;

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 7, 14, 12));
    foods = FoodRepository(db, clock.call);
    nutrition = NutritionRepository(db, foods);
    repo = FoodRegistryRepository(
      foods,
      nutrition,
      loadAsset: () async => _fixture,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'suggest matches both languages, prefix first, empty query none',
    () async {
      expect(await repo.suggest(''), isEmpty);

      final byIt = await repo.suggest('mozza');
      expect(byIt.single.id, 'mozzarella-di-bufala');

      final byEn = await repo.suggest('wheat');
      expect(byEn.single.id, 'pasta-semola-cruda');

      // Substring matches rank after prefix matches.
      final mixed = await repo.suggest('r');
      expect(mixed.first.id, 'vino-rosso'); // "Red wine" prefix
      expect(mixed, hasLength(3));
    },
  );

  test('a broken asset degrades to an empty registry', () async {
    final broken = FoodRegistryRepository(
      foods,
      nutrition,
      loadAsset: () async => 'not json at all',
    );
    expect(await broken.all(), isEmpty);
    expect(await broken.suggest('pasta'), isEmpty);
  });

  test('import creates the food with per-100g values and origin', () async {
    final pasta = (await repo.byId('pasta-semola-cruda'))!;
    final item = await repo.importIntoLibrary(pasta, languageCode: 'it');

    expect(item.name, 'Pasta di semola (cruda)');
    final library = await foods.watchLibrary().first;
    expect(library.single.category, 'Cereali e pasta');

    final facts = await nutrition.getFacts(item.id);
    expect(
      facts.per100,
      const Nutrients(
        kcal: 353,
        proteinG: 10.9,
        carbsG: 79.1,
        fatG: 1.4,
        fiberG: 2.7,
      ),
    );
    expect(facts.servingG, 80);
    expect(facts.legacyPerServing, isNull);
    expect(facts.servingDescription, 'una porzione (80 g)');

    final attributes = await foods.getAttributes(
      item.id,
      source: nutritionAttributeSource,
    );
    expect(attributes['origin'], 'registry:pasta-semola-cruda@v1');
  });

  test('import is idempotent and refreshes the stored values', () async {
    final pasta = (await repo.byId('pasta-semola-cruda'))!;
    final first = await repo.importIntoLibrary(pasta, languageCode: 'it');
    // Tamper with the stored value, then re-import.
    await nutrition.saveFacts(
      first.id,
      const NutritionFacts(per100: Nutrients(kcal: 1)),
    );
    final second = await repo.importIntoLibrary(pasta, languageCode: 'it');

    expect(second.id, first.id); // same library row, no duplicate
    expect((await nutrition.getFacts(first.id)).per100?.kcal, 353);
    expect(await foods.watchLibrary().first, hasLength(1));
  });

  test('re-importing keeps legacy per-serving values intact', () async {
    final pasta = (await repo.byId('pasta-semola-cruda'))!;
    final item = await repo.importIntoLibrary(pasta, languageCode: 'it');
    // Historical rows compute from these — an import must never eat them.
    await nutrition.saveFacts(
      item.id,
      const NutritionFacts(
        per100: Nutrients(kcal: 1),
        legacyPerServing: Nutrients(kcal: 282, proteinG: 8.7),
      ),
    );

    await repo.importIntoLibrary(pasta, languageCode: 'it');

    final facts = await nutrition.getFacts(item.id);
    expect(facts.per100?.kcal, 353); // refreshed
    expect(
      facts.legacyPerServing,
      const Nutrients(kcal: 282, proteinG: 8.7), // preserved
    );
  });

  test('the English locale imports English names and descriptions', () async {
    final wine = (await repo.byId('vino-rosso'))!;
    final item = await repo.importIntoLibrary(wine, languageCode: 'en');

    expect(item.name, 'Red wine (100 ml)');
    final facts = await nutrition.getFacts(item.id);
    expect(facts.servingDescription, 'one glass (125 ml)');
    expect(facts.per100?.kcal, 76);
    expect(facts.servingG, 125);
  });

  test('upgradeImportedFoods derives per-100g for pre-v0.5 imports', () async {
    // A food imported before v0.5: legacy per-serving values + origin,
    // no per-100g base.
    final item = await foods.getOrCreateByName('Pasta di semola (cruda)');
    await nutrition.saveFacts(
      item.id,
      const NutritionFacts(
        legacyPerServing: Nutrients(kcal: 282, proteinG: 8.7),
        servingDescription: 'una porzione (80 g)',
      ),
    );
    await foods.setAttribute(
      foodItemId: item.id,
      source: nutritionAttributeSource,
      key: nutritionOriginKey,
      value: 'registry:pasta-semola-cruda@v1',
    );
    // A manual food must never be touched.
    final manual = await foods.getOrCreateByName('Torta della nonna');
    await nutrition.saveFacts(
      manual.id,
      const NutritionFacts(legacyPerServing: Nutrients(kcal: 400)),
    );

    expect(await repo.upgradeImportedFoods(), 1);

    final facts = await nutrition.getFacts(item.id);
    expect(facts.per100?.kcal, 353);
    expect(facts.servingG, 80);
    // Legacy values and the stored description survive for history.
    expect(
      facts.legacyPerServing,
      const Nutrients(kcal: 282, proteinG: 8.7),
    );
    expect(facts.servingDescription, 'una porzione (80 g)');
    expect(
      await nutrition.getFacts(manual.id),
      const NutritionFacts(legacyPerServing: Nutrients(kcal: 400)),
    );

    // Idempotent: a second pass rewrites the same values harmlessly.
    expect(await repo.upgradeImportedFoods(), 1);
    expect((await nutrition.getFacts(item.id)).per100?.kcal, 353);
  });

  test('upgradeImportedFoods skips origins missing from the asset', () async {
    final item = await foods.getOrCreateByName('Cibo scomparso');
    await foods.setAttribute(
      foodItemId: item.id,
      source: nutritionAttributeSource,
      key: nutritionOriginKey,
      value: 'registry:voce-rimossa@v1',
    );

    expect(await repo.upgradeImportedFoods(), 0);
    expect((await nutrition.getFacts(item.id)).isEmpty, isTrue);
  });
}
