import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/meals/domain/food_item.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/nutrition/domain/nutrition_facts.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Editor for one food's nutrition estimates on the per-100g base, plus
/// the typical serving weight used to prefill meal amounts. Every field is
/// optional; clearing one removes the stored value on save. Foods that
/// only carry legacy per-serving values get a one-tap conversion.
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
  }) => showWith(context, ref.read(nutritionRepositoryProvider), food: food);

  /// Same, from a pre-captured repository — for callers whose `ref` may be
  /// gone by the time this runs (e.g. a SnackBar action after a sheet
  /// closed).
  static Future<void> showWith(
    BuildContext context,
    NutritionRepository nutrition, {
    required FoodItem food,
  }) async {
    final initial = await nutrition.getFacts(food.id);
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
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;
  late final TextEditingController _servingWeight;
  late final TextEditingController _servingDesc;
  var _saving = false;

  /// Foods edited before v0.5 carry only per-serving values; the banner
  /// offers converting them once a serving weight is typed.
  bool get _legacyOnly =>
      widget.initial.per100 == null && widget.initial.legacyPerServing != null;

  @override
  void initState() {
    super.initState();
    final per100 = widget.initial.per100;
    _kcal = TextEditingController(text: _format(per100?.kcal));
    _protein = TextEditingController(text: _format(per100?.proteinG));
    _carbs = TextEditingController(text: _format(per100?.carbsG));
    _fat = TextEditingController(text: _format(per100?.fatG));
    _fiber = TextEditingController(text: _format(per100?.fiberG));
    _servingWeight = TextEditingController(
      text: _format(widget.initial.servingG),
    );
    _servingDesc = TextEditingController(
      text: widget.initial.servingDescription ?? '',
    );
  }

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _servingWeight.dispose();
    _servingDesc.dispose();
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

  /// Fills the per-100g fields from the legacy per-serving values and the
  /// typed serving weight: per100 = perServing ÷ servingG × 100.
  void _convertLegacy() {
    final legacy = widget.initial.legacyPerServing;
    final servingG = _parse(_servingWeight.text, null);
    if (legacy == null || servingG == null || servingG <= 0) return;
    String converted(double? perServing) {
      if (perServing == null) return '';
      final per100 = perServing / servingG * 100;
      return _format((per100 * 10).roundToDouble() / 10);
    }

    setState(() {
      _kcal.text = converted(legacy.kcal);
      _protein.text = converted(legacy.proteinG);
      _carbs.text = converted(legacy.carbsG);
      _fat.text = converted(legacy.fatG);
      _fiber.text = converted(legacy.fiberG);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final per100 = widget.initial.per100;
    final servingDesc = _servingDesc.text.trim();
    final edited = Nutrients(
      kcal: _parse(_kcal.text, per100?.kcal),
      proteinG: _parse(_protein.text, per100?.proteinG),
      carbsG: _parse(_carbs.text, per100?.carbsG),
      fatG: _parse(_fat.text, per100?.fatG),
      fiberG: _parse(_fiber.text, per100?.fiberG),
    );
    final facts = NutritionFacts(
      per100: edited.isEmpty ? null : edited,
      servingG: _parse(_servingWeight.text, widget.initial.servingG),
      // Historical meal rows keep computing from the legacy values, so the
      // per-100g editor never touches them.
      legacyPerServing: widget.initial.legacyPerServing,
      servingDescription: servingDesc.isEmpty ? null : servingDesc,
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

    TextField numberField(
      TextEditingController controller,
      String label, {
      String suffix = 'g',
    }) => TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );

    final previewKcal = _parse(_kcal.text, null);
    final previewServing = _parse(_servingWeight.text, null);

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
        if (_legacyOnly) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionLegacyDetected,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_parse(_servingWeight.text, null) ?? 0) > 0
                        ? _convertLegacy
                        : null,
                    child: Text(l10n.nutritionConvertAction),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        numberField(_kcal, l10n.nutritionKcalPer100, suffix: 'kcal'),
        const SizedBox(height: 16),
        numberField(_protein, l10n.nutritionProteinLabel),
        const SizedBox(height: 16),
        numberField(_carbs, l10n.nutritionCarbsLabel),
        const SizedBox(height: 16),
        numberField(_fat, l10n.nutritionFatLabel),
        const SizedBox(height: 16),
        numberField(_fiber, l10n.nutritionFiberLabel),
        const SizedBox(height: 16),
        numberField(_servingWeight, l10n.nutritionServingWeightLabel),
        const SizedBox(height: 16),
        TextField(
          controller: _servingDesc,
          decoration: InputDecoration(
            labelText: l10n.nutritionServingDescription,
          ),
        ),
        if (previewKcal != null && previewServing != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.nutritionServingPreview(
              _format(previewServing),
              (previewKcal * previewServing / 100).round(),
            ),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}
