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
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/features/nutrition/presentation/food_nutrition_sheet.dart';
import 'package:gut_journey/features/registry/data/food_registry_repository.dart';
import 'package:gut_journey/features/registry/domain/registry_food.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final foodSuggestionsProvider = FutureProvider.autoDispose
    .family<List<FoodItem>, String>(
      (ref, query) => ref.watch(foodRepositoryProvider).suggest(query),
    );

/// A food picked in the sheet: either from the library (has an [item]) or
/// typed inline (library entry created on save). Each row owns its grams
/// field; the legacy [quantity] multiplier only rides along for rows that
/// came from historical meals.
class _PickedFood {
  _PickedFood({
    required this.name,
    this.item,
    this.portionDescription,
    this.quantity,
    double? initialAmountG,
  }) : amount = TextEditingController(
         text: initialAmountG == null ? '' : _formatAmount(initialAmountG),
       );

  final String name;
  final FoodItem? item;
  final String? portionDescription;

  /// Legacy serving multiplier of a historical row; never set for new picks.
  final double? quantity;

  /// The grams field of this row; empty means "amount unknown".
  final TextEditingController amount;

  /// Loaded lazily after the pick — drives the live kcal figure.
  NutritionFacts? facts;

  double? get amountG {
    final parsed = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    return (parsed == null || parsed <= 0) ? null : parsed;
  }

  /// Live kcal via the same engine the aggregates use, so the row always
  /// previews exactly what will count after save.
  double? get kcal => facts?.kcalFor(amountG: amountG, quantity: quantity);

  /// Whole numbers without the trailing `.0`, so 80.0 edits as "80".
  static String _formatAmount(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  MealItemInput toInput() {
    final id = item?.id;
    return id != null
        ? MealItemInput.existing(
            foodItemId: id,
            portionDescription: portionDescription,
            quantity: quantity,
            amountG: amountG,
          )
        : MealItemInput.newFood(
            name: name,
            portionDescription: portionDescription,
            quantity: quantity,
            amountG: amountG,
          );
  }

  void dispose() => amount.dispose();
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

  /// Every row ever created, so removed rows still get their grams
  /// controller disposed with the sheet.
  final _created = <_PickedFood>[];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? _guessTypeFor(ref.read(clockProvider)());
    _picked = [
      for (final item in existing?.items ?? const <MealItem>[])
        _PickedFood(
          name: item.food.name,
          item: item.food,
          portionDescription: item.portionDescription,
          quantity: item.quantity,
          initialAmountG: item.amountG,
        ),
    ];
    _created.addAll(_picked);
    for (final food in _picked) {
      // Facts only — an edited meal must not have its amounts rewritten.
      unawaited(_hydrate(food, prefill: false));
    }
    _search = TextEditingController();
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    for (final food in _created) {
      food.dispose();
    }
    _search.dispose();
    _notes.dispose();
    super.dispose();
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
      if (!alreadyPicked) {
        _picked = [..._picked, food];
        _created.add(food);
        unawaited(_hydrate(food, prefill: true));
      }
      _query = '';
      _search.clear();
    });
  }

  /// Loads the food's facts for the live kcal figure; with [prefill], an
  /// empty grams field gets the last amount logged for this food, falling
  /// back to its typical serving weight.
  Future<void> _hydrate(_PickedFood food, {required bool prefill}) async {
    final item = food.item;
    if (item == null) return;
    final facts = await ref.read(nutritionRepositoryProvider).getFacts(item.id);
    double? prefillAmount;
    if (prefill && food.amount.text.isEmpty) {
      prefillAmount =
          await ref.read(mealRepositoryProvider).lastAmountFor(item.id) ??
          facts.servingG;
    }
    if (!mounted) return;
    setState(() {
      food.facts = facts;
      if (prefillAmount != null) {
        food.amount.text = _PickedFood._formatAmount(prefillAmount);
      }
    });
  }

  /// Steps a row's grams by [delta], clamped at zero (empty field).
  void _stepAmount(_PickedFood food, double delta) {
    final next = ((food.amountG ?? 0) + delta).clamp(0.0, 9999.0);
    setState(() {
      food.amount.text = next <= 0 ? '' : _PickedFood._formatAmount(next);
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
        if (food.item == null) food.name,
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
              amountG: item.amountG,
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
        else ...[
          for (final food in _picked) _pickedRow(l10n, food),
          if (_totalKcal() case final total?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    l10n.mealTotalKcal(total.round()),
                    key: ValueKey(total.round()),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          if (_totalMacros() case final macros?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  l10n.mealMacroSummary(
                    (macros.proteinG ?? 0).round(),
                    (macros.carbsG ?? 0).round(),
                    (macros.fatG ?? 0).round(),
                    (macros.fiberG ?? 0).round(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
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

  /// Sum of the rows whose kcal are computable; null hides the total
  /// entirely (no data ≠ zero, same rule as the Today card).
  double? _totalKcal() {
    final values = [for (final food in _picked) ?food.kcal];
    if (values.isEmpty) return null;
    var total = 0.0;
    for (final kcal in values) {
      total += kcal;
    }
    return total;
  }

  /// Macro totals across the computable rows, or null when no row
  /// contributes any macro — the compact "meal detail" line.
  Nutrients? _totalMacros() {
    Nutrients? total;
    for (final food in _picked) {
      final nutrients = food.facts?.nutrientsFor(
        amountG: food.amountG,
        quantity: food.quantity,
      );
      if (nutrients == null) continue;
      total = total == null ? nutrients : total + nutrients;
    }
    if (total == null) return null;
    final hasMacro =
        total.proteinG != null ||
        total.carbsG != null ||
        total.fatG != null ||
        total.fiberG != null;
    return hasMacro ? total : null;
  }

  /// One picked food: name, compact grams field with ± stepper, live kcal
  /// and remove — replacing the old ×½/×1/×2 cycling chips.
  Widget _pickedRow(AppLocalizations l10n, _PickedFood food) {
    final theme = Theme.of(context);
    final kcal = food.kcal;
    final facts = food.facts;
    // Offer the editor when this row can't produce kcal: grams typed but
    // no per-100g base, or no basis at all. An empty grams field on a
    // per-100g food just wants a number typed, not the editor.
    final needsValues =
        kcal == null &&
        food.item != null &&
        facts != null &&
        (food.amountG != null ? facts.per100 == null : !facts.hasKcalBasis);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (needsValues)
                  InkWell(
                    onTap: () => unawaited(_editValues(food)),
                    child: Text(
                      l10n.nutritionAddValuesAction,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove,
            tooltip: l10n.mealDecreaseAmount,
            onStep: () => _stepAmount(food, -10),
          ),
          SizedBox(
            width: 76,
            child: TextField(
              key: ValueKey('amount:${food.name}'),
              controller: food.amount,
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'g',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: l10n.mealIncreaseAmount,
            onStep: () => _stepAmount(food, 10),
          ),
          SizedBox(
            width: 72,
            child: Text(
              kcal == null ? '—' : l10n.mealItemKcal(kcal.round()),
              textAlign: TextAlign.end,
              style: kcal == null
                  ? theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.delete,
            onPressed: () =>
                setState(() => _picked = [..._picked]..remove(food)),
          ),
        ],
      ),
    );
  }

  /// Opens the nutrition editor for a picked food, then refreshes the row —
  /// including the grams prefill, now that a serving weight may exist.
  Future<void> _editValues(_PickedFood food) async {
    final item = food.item;
    if (item == null) return;
    await FoodNutritionSheet.show(context, ref, food: item);
    if (!mounted) return;
    await _hydrate(food, prefill: true);
  }

  /// Imports a registry food into the library (values included) and picks
  /// it like any existing food — zero extra taps over a normal suggestion.
  Future<void> _pickFromRegistry(RegistryFood food) async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final item = await ref
        .read(foodRegistryRepositoryProvider)
        .importIntoLibrary(food, languageCode: languageCode);
    if (!mounted) return;
    _addFood(_PickedFood(name: item.name, item: item));
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
                  _addFood(_PickedFood(name: item.name, item: item)),
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

/// A compact stepper button: tap steps once, long-press keeps stepping.
class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onStep,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: (_) {
      widget.onStep();
      _repeat = Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => widget.onStep(),
      );
    },
    onLongPressEnd: (_) => _stop(),
    onLongPressCancel: _stop,
    child: IconButton(
      icon: Icon(widget.icon, size: 20),
      visualDensity: VisualDensity.compact,
      tooltip: widget.tooltip,
      onPressed: widget.onStep,
    ),
  );
}
