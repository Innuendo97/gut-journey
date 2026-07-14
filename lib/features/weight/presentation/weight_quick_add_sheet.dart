import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/weight/data/weight_repository.dart';
import 'package:gut_journey/features/weight/domain/weight_entry.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

final FutureProvider<WeightEntry?> latestWeightProvider =
    FutureProvider.autoDispose<WeightEntry?>(
      (ref) => ref.watch(weightRepositoryProvider).getLatest(),
    );

class WeightQuickAddSheet extends ConsumerStatefulWidget {
  const WeightQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final WeightEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    WeightEntry? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => WeightQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<WeightQuickAddSheet> createState() =>
      _WeightQuickAddSheetState();
}

class _WeightQuickAddSheetState extends ConsumerState<WeightQuickAddSheet> {
  late final TextEditingController _weight;
  var _prefilled = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _weight = TextEditingController(
      text: existing != null ? _format(existing.weightKg) : '',
    );
    _prefilled = existing != null;
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  static String _format(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

  Future<void> _save() async {
    final parsed = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0 || parsed > 500) {
      setState(
        () => _error = AppLocalizations.of(context).weightInvalid,
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(weightRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      final now = ref.read(clockProvider)();
      final occurredAt = LocalDay.fromDateTime(now) == widget.day
          ? now
          : widget.day.toDateTime().add(const Duration(hours: 8));
      await repo.add(weightKg: parsed, occurredAt: occurredAt);
    } else {
      await repo.update(existing.copyWith(weightKg: parsed));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Pre-fill with the last known weight: usually the user just tweaks it.
    if (!_prefilled) {
      final latest = ref.watch(latestWeightProvider).value;
      if (latest != null && _weight.text.isEmpty) {
        _weight.text = _format(latest.weightKg);
        _prefilled = true;
      }
    }

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.weightSheetTitle
          : l10n.weightSheetEditTitle,
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
        TextField(
          controller: _weight,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.weightKgLabel,
            errorText: _error,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
