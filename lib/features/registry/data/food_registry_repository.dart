import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/registry/domain/registry_food.dart';

/// Provenance attribute written on import: `(nutrition, origin)` →
/// `registry:<id>@v<version>`, so future registry updates can tell which
/// library values came from it.
const nutritionOriginKey = 'origin';

final foodRegistryRepositoryProvider = Provider<FoodRegistryRepository>(
  (ref) => FoodRegistryRepository(
    ref.watch(foodRepositoryProvider),
    ref.watch(nutritionRepositoryProvider),
  ),
);

/// Estimated kcal-suggestions from the bundled registry, by query.
final registrySuggestionsProvider = FutureProvider.autoDispose
    .family<List<RegistryFood>, String>(
      (ref, query) => ref.watch(foodRegistryRepositoryProvider).suggest(query),
    );

/// The bundled food registry: ~600 foods with average per-100g values and
/// typical servings, searched for suggestions and imported into the
/// personal library on first use. Read-only; the user's library remains
/// the single source of truth after import.
class FoodRegistryRepository {
  FoodRegistryRepository(
    this._foods,
    this._nutrition, {
    Future<String> Function()? loadAsset,
  }) : _loadAsset = loadAsset ?? _defaultLoadAsset;

  static const assetPath = 'assets/data/food_registry_v1.json';
  static const version = 1;

  final FoodRepository _foods;
  final NutritionRepository _nutrition;
  final Future<String> Function() _loadAsset;
  Future<List<RegistryFood>>? _cache;

  static Future<String> _defaultLoadAsset() => rootBundle.loadString(assetPath);

  /// Loaded and parsed once per app run; a broken asset degrades to an
  /// empty registry instead of breaking the meal flow.
  Future<List<RegistryFood>> all() => _cache ??= _parse();

  Future<List<RegistryFood>> _parse() async {
    try {
      final data = jsonDecode(await _loadAsset()) as Map<String, dynamic>;
      return [
        for (final food in data['foods'] as List<dynamic>)
          RegistryFood.fromJson(food as Map<String, dynamic>),
      ];
    } on Exception catch (error) {
      debugPrint('food registry unavailable: $error');
      return const [];
    }
  }

  /// Substring match on both languages, prefix matches first, then
  /// alphabetical by Italian name. Empty queries return nothing — the
  /// registry suggests, it does not browse itself into the quick flow.
  Future<List<RegistryFood>> suggest(String query, {int limit = 5}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final matches = [
      for (final food in await all())
        if (food.nameIt.toLowerCase().contains(needle) ||
            food.nameEn.toLowerCase().contains(needle))
          food,
    ];
    int rank(RegistryFood food) =>
        food.nameIt.toLowerCase().startsWith(needle) ||
            food.nameEn.toLowerCase().startsWith(needle)
        ? 0
        : 1;
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.nameIt.compareTo(b.nameIt);
    });
    return matches.take(limit).toList();
  }

  Future<RegistryFood?> byId(String id) async {
    for (final food in await all()) {
      if (food.id == id) return food;
    }
    return null;
  }

  /// Creates (or finds, case-insensitively) the library food for [food] in
  /// the given language and stores its per-serving estimates plus category
  /// and provenance. Idempotent: importing again refreshes the values.
  Future<FoodItem> importIntoLibrary(
    RegistryFood food, {
    required String languageCode,
  }) async {
    final item = await _foods.getOrCreateByName(food.name(languageCode));
    await _foods.updateItem(
      item.copyWith(category: food.categoryLabel(languageCode)),
    );
    await _nutrition.saveFacts(item.id, food.toFacts(languageCode));
    await _foods.setAttribute(
      foodItemId: item.id,
      source: nutritionAttributeSource,
      key: nutritionOriginKey,
      value: 'registry:${food.id}@v$version',
    );
    return item;
  }
}
