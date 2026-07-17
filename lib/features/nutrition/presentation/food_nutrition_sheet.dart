import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Editor for one food's per-serving nutrition estimates. Every field is
/// optional; clearing one removes the stored value on save.
class FoodNutritionSheet extends ConsumerStatefulWidget {
  const FoodNutritionSheet({
    required this.food,
    required this.initial,
    super.key,
  });

  final FoodItem food;
  final NutritionFacts initial;

  /// Loads the stored facts, then opens the editor.
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required FoodItem food,
  }) async {
    final initial = await ref
        .read(nutritionRepositoryProvider)
        .getFacts(food.id);
    if (!context.mounted) return;
    await showQuickAddSheet<void>(
      context: context,
      builder: (_) => FoodNutritionSheet(food: food, initial: initial),
    );
  }

  @override
  ConsumerState<FoodNutritionSheet> createState() => _FoodNutritionSheetState();
}

class _FoodNutritionSheetState extends ConsumerState<FoodNutritionSheet> {
  late final TextEditingController _kcal;
  late final TextEditingController _servingDesc;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _kcal = TextEditingController(text: _format(initial.kcalPerServing));
    _servingDesc = TextEditingController(
      text: initial.servingDescription ?? '',
    );
    _protein = TextEditingController(text: _format(initial.proteinG));
    _carbs = TextEditingController(text: _format(initial.carbsG));
    _fat = TextEditingController(text: _format(initial.fatG));
    _fiber = TextEditingController(text: _format(initial.fiberG));
  }

  @override
  void dispose() {
    _kcal.dispose();
    _servingDesc.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    super.dispose();
  }

  /// Whole numbers without the trailing `.0`, so 220.0 edits as "220".
  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? '${value.round()}' : '$value';
  }

  /// Empty → null (removes the stored value); unparseable → the previous
  /// value, so a typo never silently destroys an estimate.
  static double? _parse(String text, double? previous) {
    final trimmed = text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed) ?? previous;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final initial = widget.initial;
    final servingDesc = _servingDesc.text.trim();
    final facts = NutritionFacts(
      kcalPerServing: _parse(_kcal.text, initial.kcalPerServing),
      servingDescription: servingDesc.isEmpty ? null : servingDesc,
      proteinG: _parse(_protein.text, initial.proteinG),
      carbsG: _parse(_carbs.text, initial.carbsG),
      fatG: _parse(_fat.text, initial.fatG),
      fiberG: _parse(_fiber.text, initial.fiberG),
    );
    await ref
        .read(nutritionRepositoryProvider)
        .saveFacts(widget.food.id, facts);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    TextField numberField(TextEditingController controller, String label) =>
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, suffixText: 'g'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );

    return SheetScaffold(
      title: widget.food.name,
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
        Text(
          l10n.nutritionSheetDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _kcal,
          decoration: InputDecoration(
            labelText: l10n.nutritionKcalPerServing,
            suffixText: 'kcal',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _servingDesc,
          decoration: InputDecoration(
            labelText: l10n.nutritionServingDescription,
          ),
        ),
        const SizedBox(height: 16),
        numberField(_protein, l10n.nutritionProteinLabel),
        const SizedBox(height: 16),
        numberField(_carbs, l10n.nutritionCarbsLabel),
        const SizedBox(height: 16),
        numberField(_fat, l10n.nutritionFatLabel),
        const SizedBox(height: 16),
        numberField(_fiber, l10n.nutritionFiberLabel),
      ],
    );
  }
}
