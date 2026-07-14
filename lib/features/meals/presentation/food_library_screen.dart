import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.foodLibraryTitle)),
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
                  return ListTile(
                    title: Text(food.name),
                    subtitle: Text(
                      [
                        if (food.category != null) food.category!,
                        l10n.foodUsageCount(food.usageCount),
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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => unawaited(_delete(food)),
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
    final nameController = TextEditingController(text: food.name);
    final categoryController = TextEditingController(
      text: food.category ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editFood),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.foodNameLabel),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(labelText: l10n.foodCategoryLabel),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved ?? false) {
      final name = nameController.text.trim();
      final category = categoryController.text.trim();
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
    nameController.dispose();
    categoryController.dispose();
  }
}
