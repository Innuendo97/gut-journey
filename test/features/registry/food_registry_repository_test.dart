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

  test('import creates the food with per-serving values and origin', () async {
    final pasta = (await repo.byId('pasta-semola-cruda'))!;
    final item = await repo.importIntoLibrary(pasta, languageCode: 'it');

    expect(item.name, 'Pasta di semola (cruda)');
    final library = await foods.watchLibrary().first;
    expect(library.single.category, 'Cereali e pasta');

    final facts = await nutrition.getFacts(item.id);
    // 353 kcal/100g × 80 g = 282.4 → whole kcal; macros to one decimal.
    expect(facts.legacyPerServing?.kcal, 282);
    expect(facts.legacyPerServing?.proteinG, 8.7);
    expect(facts.legacyPerServing?.carbsG, 63.3);
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
      const NutritionFacts(legacyPerServing: Nutrients(kcal: 1)),
    );
    final second = await repo.importIntoLibrary(pasta, languageCode: 'it');

    expect(second.id, first.id); // same library row, no duplicate
    expect(
      (await nutrition.getFacts(first.id)).legacyPerServing?.kcal,
      282,
    );
    expect(await foods.watchLibrary().first, hasLength(1));
  });

  test('the English locale imports English names and descriptions', () async {
    final wine = (await repo.byId('vino-rosso'))!;
    final item = await repo.importIntoLibrary(wine, languageCode: 'en');

    expect(item.name, 'Red wine (100 ml)');
    final facts = await nutrition.getFacts(item.id);
    expect(facts.servingDescription, 'one glass (125 ml)');
    expect(facts.legacyPerServing?.kcal, 95); // 76 × 1.25
  });
}
