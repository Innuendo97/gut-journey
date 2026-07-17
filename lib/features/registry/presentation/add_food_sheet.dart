import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/presentation/food_nutrition_sheet.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';
import 'package:gut_journey/features/registry/domain/registry_food.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Adds a food to the library: search the bundled registry and import a
/// match (values included), or create a custom food and go straight to its
/// nutrition editor.
class AddFoodSheet extends ConsumerStatefulWidget {
  const AddFoodSheet({super.key});

  static Future<void> show(BuildContext context) => showQuickAddSheet(
    context: context,
    builder: (_) => const AddFoodSheet(),
  );

  @override
  ConsumerState<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<AddFoodSheet> {
  var _query = '';

  Future<void> _import(RegistryFood food) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final registry = ref.read(foodRegistryRepositoryProvider);
    final item = await registry.importIntoLibrary(
      food,
      languageCode: languageCode,
    );
    if (mounted) Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.foodImportedSnack(item.name))),
    );
  }

  Future<void> _createCustom(String name) async {
    final foods = ref.read(foodRepositoryProvider);
    final nutrition = ref.read(nutritionRepositoryProvider);
    final navigator = Navigator.of(context);
    final item = await foods.getOrCreateByName(name);
    if (mounted) Navigator.of(context).pop();
    if (!navigator.mounted) return;
    // Straight into the values editor — the reason the user came here.
    unawaited(
      FoodNutritionSheet.showWith(navigator.context, nutrition, food: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final matches =
        ref.watch(registrySuggestionsProvider(_query)).value ??
        const <RegistryFood>[];
    final trimmed = _query.trim();
    final hasExactRegistryMatch = matches.any(
      (m) => m.name(languageCode).toLowerCase() == trimmed.toLowerCase(),
    );

    return SheetScaffold(
      title: l10n.foodAddAction,
      children: [
        TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.foodRegistrySearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        for (final food in matches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(food.name(languageCode)),
            subtitle: Text(
              '${l10n.nutritionFoodKcalSubtitle(food.kcalPerServing.round())}'
              ' · ${food.categoryLabel(languageCode)}',
            ),
            onTap: () => unawaited(_import(food)),
          ),
        if (trimmed.isNotEmpty && !hasExactRegistryMatch)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add),
            title: Text(l10n.foodCreateCustom(trimmed)),
            onTap: () => unawaited(_createCustom(trimmed)),
          ),
      ],
    );
  }
}
