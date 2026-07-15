import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/meals/data/meal_repository.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/meals/domain/meal_entry.dart';
import 'package:gut_journey/features/meals/domain/meal_type.dart';
import 'package:gut_journey/features/meals/presentation/meal_type_icon.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final foodSuggestionsProvider = FutureProvider.autoDispose
    .family<List<FoodItem>, String>(
      (ref, query) => ref.watch(foodRepositoryProvider).suggest(query),
    );

/// A food picked in the sheet: either from the library (has an id) or typed
/// inline (library entry created on save).
class _PickedFood {
  const _PickedFood({required this.name, this.foodItemId});

  final String name;
  final String? foodItemId;

  MealItemInput toInput() {
    final id = foodItemId;
    return id != null
        ? MealItemInput.existing(foodItemId: id)
        : MealItemInput.newFood(name: name);
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
        _PickedFood(name: item.food.name, foodItemId: item.food.id),
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

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.mealSheetTitle
          : l10n.mealSheetEditTitle,
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
        ..._buildSuggestions(l10n, suggestions),
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
                  label: Text(food.name),
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

  List<Widget> _buildSuggestions(
    AppLocalizations l10n,
    AsyncValue<List<FoodItem>> suggestions,
  ) {
    final pickedNames = {for (final f in _picked) f.name.toLowerCase()};
    final items = suggestions.value ?? const <FoodItem>[];
    final visible = [
      for (final item in items)
        if (!pickedNames.contains(item.name.toLowerCase())) item,
    ];
    final trimmedQuery = _query.trim();
    final hasExactMatch = items.any(
      (i) => i.name.toLowerCase() == trimmedQuery.toLowerCase(),
    );
    if (visible.isEmpty && (trimmedQuery.isEmpty || hasExactMatch)) {
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
        ],
      ),
    ];
  }
}
