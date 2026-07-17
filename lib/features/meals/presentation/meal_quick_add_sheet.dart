import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/delete_entry_with_undo.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/meals/presentation/meal_type_icon.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/presentation/food_nutrition_sheet.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';
import 'package:gut_journey/features/registry/domain/registry_food.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final foodSuggestionsProvider = FutureProvider.autoDispose
    .family<List<FoodItem>, String>(
      (ref, query) => ref.watch(foodRepositoryProvider).suggest(query),
    );

/// A food picked in the sheet: either from the library (has an id) or typed
/// inline (library entry created on save).
class _PickedFood {
  const _PickedFood({
    required this.name,
    this.foodItemId,
    this.portionDescription,
    this.quantity = 1,
  });

  final String name;
  final String? foodItemId;
  final String? portionDescription;

  /// Servings of this food, cycled by tapping the chip.
  final double quantity;

  /// Tap cycle ×1 → ×2 → ×½ → ×1; any other inherited value returns to 1.
  _PickedFood cycleQuantity() => _PickedFood(
    name: name,
    foodItemId: foodItemId,
    portionDescription: portionDescription,
    quantity: quantity == 1
        ? 2
        : quantity == 2
        ? 0.5
        : 1,
  );

  MealItemInput toInput() {
    final id = foodItemId;
    // One serving stays null in the database — the default needs no row
    // value and older entries mean the same thing.
    final storedQuantity = quantity == 1 ? null : quantity;
    return id != null
        ? MealItemInput.existing(
            foodItemId: id,
            portionDescription: portionDescription,
            quantity: storedQuantity,
          )
        : MealItemInput.newFood(
            name: name,
            portionDescription: portionDescription,
            quantity: storedQuantity,
          );
  }
}

class MealQuickAddSheet extends ConsumerStatefulWidget {
  const MealQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final MealEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    MealEntry? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => MealQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<MealQuickAddSheet> createState() => _MealQuickAddSheetState();
}

class _MealQuickAddSheetState extends ConsumerState<MealQuickAddSheet> {
  late MealType _type;
  late List<_PickedFood> _picked;
  late final TextEditingController _search;
  late final TextEditingController _notes;
  var _query = '';
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? _guessTypeFor(ref.read(clockProvider)());
    _picked = [
      for (final item in existing?.items ?? const <MealItem>[])
        _PickedFood(
          name: item.food.name,
          foodItemId: item.food.id,
          portionDescription: item.portionDescription,
          quantity: item.quantity ?? 1,
        ),
    ];
    _search = TextEditingController();
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// ½ for half a serving, whole numbers without a decimal point.
  static String _multiplier(double quantity) {
    if (quantity == 0.5) return '½';
    return quantity == quantity.roundToDouble()
        ? '${quantity.round()}'
        : '$quantity';
  }

  static MealType _guessTypeFor(DateTime now) {
    final hour = now.toLocal().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 18) return MealType.snack;
    return MealType.dinner;
  }

  void _addFood(_PickedFood food) {
    final alreadyPicked = _picked.any(
      (p) => p.name.toLowerCase() == food.name.toLowerCase(),
    );
    setState(() {
      if (!alreadyPicked) _picked = [..._picked, food];
      _query = '';
      _search.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(mealRepositoryProvider);
    // Captured before any await: the snackbar nudge below fires after this
    // sheet is gone, when context and ref can no longer be used.
    final foodsRepo = ref.read(foodRepositoryProvider);
    final nutrition = ref.read(nutritionRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    final newNames = [
      for (final food in _picked)
        if (food.foodItemId == null) food.name,
    ];
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final items = [for (final food in _picked) food.toInput()];
    final existing = widget.existing;
    if (existing == null) {
      await repo.createMeal(
        type: _type,
        occurredAt: _occurredAtForNewEntry(),
        items: items,
        notes: notes,
      );
    } else {
      await repo.updateMeal(
        id: existing.id,
        type: _type,
        occurredAt: existing.occurredAt,
        items: items,
        notes: notes,
      );
    }
    if (mounted) Navigator.of(context).pop();
    await _nudgeForMissingValues(
      newNames,
      foodsRepo,
      nutrition,
      messenger,
      l10n,
      navigator,
      router,
    );
  }

  /// Foods typed inline joined the library without nutrition values — offer
  /// (never demand) to add them, keeping the quick-entry flow untouched.
  static Future<void> _nudgeForMissingValues(
    List<String> newNames,
    FoodRepository foodsRepo,
    NutritionRepository nutrition,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    NavigatorState navigator,
    GoRouter router,
  ) async {
    if (newNames.isEmpty) return;
    final withoutValues = <FoodItem>[];
    for (final name in newNames) {
      // Idempotent: resolves the row the save just created.
      final item = await foodsRepo.getOrCreateByName(name);
      final facts = await nutrition.getFacts(item.id);
      if (!facts.hasKcalBasis) withoutValues.add(item);
    }
    if (withoutValues.isEmpty) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          withoutValues.length == 1
              ? l10n.nutritionNewFoodPrompt(withoutValues.single.name)
              : l10n.nutritionNewFoodsPrompt,
        ),
        action: SnackBarAction(
          label: l10n.nutritionAddValuesAction,
          onPressed: () {
            if (withoutValues.length == 1) {
              // The navigator outlives this sheet; its context is looked
              // up synchronously inside this tap handler.
              unawaited(
                FoodNutritionSheet.showWith(
                  navigator.context,
                  nutrition,
                  food: withoutValues.single,
                ),
              );
            } else {
              router.go(AppRoutes.moreFoods);
            }
          },
        ),
      ),
    );
  }

  void _delete() {
    final existing = widget.existing!;
    final repo = ref.read(mealRepositoryProvider);
    deleteEntryWithUndo(
      context,
      delete: () => repo.deleteMeal(existing.id),
      restore: () => repo.createMeal(
        type: existing.type,
        occurredAt: existing.occurredAt,
        items: [
          for (final item in existing.items)
            MealItemInput.existing(
              foodItemId: item.food.id,
              portionDescription: item.portionDescription,
              quantity: item.quantity,
            ),
        ],
        notes: existing.notes,
      ),
    );
    Navigator.of(context).pop();
  }

  /// Today's entries happen "now"; back-filled days get a sensible default
  /// hour for the meal type.
  DateTime _occurredAtForNewEntry() {
    final now = ref.read(clockProvider)();
    if (LocalDay.fromDateTime(now) == widget.day) return now;
    final hour = switch (_type) {
      MealType.breakfast => 8,
      MealType.lunch => 13,
      MealType.snack => 17,
      MealType.dinner => 20,
      MealType.drink => 11,
    };
    return widget.day.toDateTime().add(Duration(hours: hour));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions = ref.watch(foodSuggestionsProvider(_query));
    final registryMatches =
        ref.watch(registrySuggestionsProvider(_query)).value ??
        const <RegistryFood>[];
    final languageCode = Localizations.localeOf(context).languageCode;

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.mealSheetTitle
          : l10n.mealSheetEditTitle,
      destructiveAction: widget.existing == null
          ? null
          : DeleteEntryButton(onPressed: _saving ? null : _delete),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
      children: [
        // Chips instead of a SegmentedButton: five segments cannot fit the
        // longer Italian labels on a phone, chips wrap to a second row.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final type in MealType.values)
              ChoiceChip(
                avatar: Icon(mealTypeIcon(type), size: 18),
                label: Text(l10n.mealTypeLabel(type)),
                selected: _type == type,
                // The checkmark would overdraw the avatar; selection still
                // reads through color and chip semantics.
                showCheckmark: false,
                onSelected: (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: l10n.foodSearchHint,
            prefixIcon: const Icon(Icons.search),
          ),
          textInputAction: TextInputAction.done,
          onChanged: (value) => setState(() => _query = value),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) _addFood(_PickedFood(name: name));
          },
        ),
        const SizedBox(height: 8),
        ..._buildSuggestions(l10n, suggestions, registryMatches, languageCode),
        const SizedBox(height: 16),
        if (_picked.isEmpty)
          Text(
            l10n.noFoodsSelected,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final food in _picked)
                InputChip(
                  label: Text(switch (food.quantity) {
                    1 => food.name,
                    final q =>
                      '${food.name} '
                          '${l10n.mealServingMultiplier(_multiplier(q))}',
                  }),
                  // Tap cycles the servings; the fast path (one serving)
                  // needs no interaction at all.
                  onPressed: () => setState(
                    () => _picked = [
                      for (final p in _picked)
                        if (identical(p, food)) p.cycleQuantity() else p,
                    ],
                  ),
                  onDeleted: () => setState(
                    () => _picked = [..._picked]..remove(food),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          decoration: InputDecoration(
            labelText: l10n.notesLabel,
            hintText: l10n.notesHint,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  /// Imports a registry food into the library (values included) and picks
  /// it like any existing food — zero extra taps over a normal suggestion.
  Future<void> _pickFromRegistry(RegistryFood food) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final item = await ref
        .read(foodRegistryRepositoryProvider)
        .importIntoLibrary(food, languageCode: languageCode);
    if (!mounted) return;
    _addFood(_PickedFood(name: item.name, foodItemId: item.id));
  }

  List<Widget> _buildSuggestions(
    AppLocalizations l10n,
    AsyncValue<List<FoodItem>> suggestions,
    List<RegistryFood> registryMatches,
    String languageCode,
  ) {
    final pickedNames = {for (final f in _picked) f.name.toLowerCase()};
    final items = suggestions.value ?? const <FoodItem>[];
    final visible = [
      for (final item in items)
        if (!pickedNames.contains(item.name.toLowerCase())) item,
    ];
    // Registry entries hide behind their personal twin: once imported (or
    // shadowed by an own food of the same name) only the library chip shows.
    final personalNames = {
      for (final item in items) item.name.toLowerCase(),
      ...pickedNames,
    };
    final registryVisible = [
      for (final food in registryMatches)
        if (!personalNames.contains(food.name(languageCode).toLowerCase()))
          food,
    ];
    final trimmedQuery = _query.trim();
    final hasExactMatch = items.any(
      (i) => i.name.toLowerCase() == trimmedQuery.toLowerCase(),
    );
    if (visible.isEmpty &&
        registryVisible.isEmpty &&
        (trimmedQuery.isEmpty || hasExactMatch)) {
      return const [];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (trimmedQuery.isNotEmpty && !hasExactMatch)
            ActionChip(
              avatar: const Icon(Icons.add),
              label: Text(l10n.addFoodInline(trimmedQuery)),
              onPressed: () => _addFood(_PickedFood(name: trimmedQuery)),
            ),
          for (final item in visible)
            ActionChip(
              avatar: item.isFavorite ? const Icon(Icons.star, size: 18) : null,
              label: Text(item.name),
              onPressed: () =>
                  _addFood(_PickedFood(name: item.name, foodItemId: item.id)),
            ),
          for (final food in registryVisible)
            ActionChip(
              avatar: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text(food.name(languageCode)),
              onPressed: () => unawaited(_pickFromRegistry(food)),
            ),
        ],
      ),
    ];
  }
}
