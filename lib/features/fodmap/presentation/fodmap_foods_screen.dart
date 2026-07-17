import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_providers.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/presentation/food_library_screen.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Manual FODMAP tagging of the personal food library: each food can carry
/// the group agreed with the user's dietitian.
class FodmapFoodsScreen extends ConsumerWidget {
  const FodmapFoodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final foods = ref.watch(foodLibraryProvider(''));
    final groupByFood =
        ref.watch(fodmapGroupByFoodProvider).value ?? const <String, String>{};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fodmapTagFoods)),
      body: switch (foods) {
        AsyncValue(value: final items?) when items.isEmpty => EmptyState(
          icon: Icons.restaurant_outlined,
          title: l10n.noFoodsYet,
        ),
        AsyncValue(value: final items?) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final food = items[index];
            final group = _storedGroup(groupByFood[food.id]);
            return ListTile(
              title: Text(food.name),
              subtitle: Text(switch (group) {
                final g? => l10n.fodmapGroupLabel(g),
                null => l10n.fodmapNoGroup,
              }),
              trailing: const Icon(Icons.sell_outlined),
              onTap: () => unawaited(_pickGroup(context, ref, food, group)),
            );
          },
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  FodmapGroup? _storedGroup(String? name) {
    for (final group in FodmapGroup.values) {
      if (group.name == name) return group;
    }
    return null;
  }

  Future<void> _pickGroup(
    BuildContext context,
    WidgetRef ref,
    FoodItem food,
    FodmapGroup? current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showQuickAddSheet<(FodmapGroup?,)>(
      context: context,
      builder: (context) => SheetScaffold(
        title: food.name,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in FodmapGroup.values)
                ChoiceChip(
                  label: Text(l10n.fodmapGroupLabel(group)),
                  selected: current == group,
                  onSelected: (_) => Navigator.of(context).pop((group,)),
                ),
              ChoiceChip(
                label: Text(l10n.fodmapNoGroup),
                selected: current == null,
                onSelected: (_) => Navigator.of(context).pop((null,)),
              ),
            ],
          ),
        ],
      ),
    );
    if (choice == null) return;

    final repo = ref.read(foodRepositoryProvider);
    switch (choice) {
      case (final FodmapGroup group,):
        await repo.setAttribute(
          foodItemId: food.id,
          source: fodmapAttributeSource,
          key: fodmapAttributeKey,
          value: group.name,
        );
      case (null,):
        await repo.removeAttribute(
          foodItemId: food.id,
          source: fodmapAttributeSource,
          key: fodmapAttributeKey,
        );
    }
  }
}
