import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/core/widgets/text_input_dialog.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/nutrition/presentation/food_nutrition_sheet.dart';
import 'package:gut_journey/features/nutrition/presentation/nutrition_providers.dart';
import 'package:gut_journey/features/registry/presentation/add_food_sheet.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final foodLibraryProvider = StreamProvider.autoDispose
    .family<List<FoodItem>, String>(
      (ref, query) => ref
          .watch(foodRepositoryProvider)
          .watchLibrary(
            query: query,
          ),
    );

class FoodLibraryScreen extends ConsumerStatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  ConsumerState<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends ConsumerState<FoodLibraryScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foods = ref.watch(foodLibraryProvider(_query));
    final kcalByFood = ref.watch(kcalByFoodProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foodLibraryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(AddFoodSheet.show(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.foodAddAction),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.searchFoodsHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: switch (foods) {
              AsyncValue(value: final items?) when items.isEmpty => EmptyState(
                icon: Icons.restaurant_outlined,
                title: l10n.noFoodsYet,
              ),
              AsyncValue(value: final items?) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final food = items[index];
                  final kcal = kcalByFood[food.id];
                  return ListTile(
                    title: Text(food.name),
                    subtitle: Text(
                      [
                        if (food.category != null) food.category!,
                        l10n.foodUsageCount(food.usageCount),
                        if (kcal != null)
                          kcal.per100
                              ? l10n.nutritionFoodKcal100Subtitle(
                                  kcal.kcal.round(),
                                )
                              : l10n.nutritionFoodKcalSubtitle(
                                  kcal.kcal.round(),
                                ),
                      ].join(' · '),
                    ),
                    leading: IconButton(
                      icon: Icon(
                        food.isFavorite ? Icons.star : Icons.star_border,
                      ),
                      color: food.isFavorite
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      onPressed: () => unawaited(
                        ref
                            .read(foodRepositoryProvider)
                            .setFavorite(
                              food.id,
                              isFavorite: !food.isFavorite,
                            ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.local_fire_department_outlined,
                          ),
                          tooltip: l10n.nutritionEditFacts,
                          onPressed: () => unawaited(
                            FoodNutritionSheet.show(context, ref, food: food),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => unawaited(_delete(food)),
                        ),
                      ],
                    ),
                    onTap: () => unawaited(_edit(food)),
                  );
                },
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _delete(FoodItem food) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await ref.read(foodRepositoryProvider).delete(food.id);
    if (!deleted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.foodInUse)));
    }
  }

  Future<void> _edit(FoodItem food) async {
    final l10n = AppLocalizations.of(context);
    final values = await TextInputDialog.show(
      context,
      title: l10n.editFood,
      fields: [
        TextInputField(label: l10n.foodNameLabel, initialValue: food.name),
        TextInputField(
          label: l10n.foodCategoryLabel,
          initialValue: food.category ?? '',
        ),
      ],
    );
    if (values == null) return;
    final name = values[0].trim();
    final category = values[1].trim();
    if (name.isNotEmpty) {
      await ref
          .read(foodRepositoryProvider)
          .updateItem(
            food.copyWith(
              name: name,
              category: category.isEmpty ? null : category,
            ),
          );
    }
  }
}
