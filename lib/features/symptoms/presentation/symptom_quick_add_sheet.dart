import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/delete_entry_with_undo.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

class SymptomQuickAddSheet extends ConsumerStatefulWidget {
  const SymptomQuickAddSheet({required this.day, this.existing, super.key});

  final LocalDay day;
  final SymptomEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required LocalDay day,
    SymptomEntry? existing,
  }) => showQuickAddSheet(
    context: context,
    builder: (_) => SymptomQuickAddSheet(day: day, existing: existing),
  );

  @override
  ConsumerState<SymptomQuickAddSheet> createState() =>
      _SymptomQuickAddSheetState();
}

class _SymptomQuickAddSheetState extends ConsumerState<SymptomQuickAddSheet> {
  String? _typeId;
  late int _intensity;
  late final TextEditingController _duration;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _typeId = widget.existing?.symptomTypeId;
    _intensity = widget.existing?.intensity ?? 5;
    _duration = TextEditingController(
      text: widget.existing?.durationMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final typeId = _typeId;
    if (typeId == null) return;
    setState(() => _saving = true);
    final repo = ref.read(symptomRepositoryProvider);
    final duration = int.tryParse(_duration.text.trim());
    final existing = widget.existing;
    if (existing == null) {
      final now = ref.read(clockProvider)();
      final occurredAt = LocalDay.fromDateTime(now) == widget.day
          ? now
          : widget.day.toDateTime().add(const Duration(hours: 12));
      await repo.addEntry(
        symptomTypeId: typeId,
        intensity: _intensity,
        occurredAt: occurredAt,
        durationMinutes: duration,
      );
    } else {
      await repo.updateEntry(
        existing.copyWith(
          symptomTypeId: typeId,
          intensity: _intensity,
          durationMinutes: duration,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() {
    final existing = widget.existing!;
    final repo = ref.read(symptomRepositoryProvider);
    deleteEntryWithUndo(
      context,
      delete: () => repo.deleteEntry(existing.id),
      restore: () => repo.addEntry(
        symptomTypeId: existing.symptomTypeId,
        intensity: existing.intensity,
        occurredAt: existing.occurredAt,
        durationMinutes: existing.durationMinutes,
        notes: existing.notes,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final types = ref.watch(symptomTypesProvider).value ?? const [];

    return SheetScaffold(
      title: widget.existing == null
          ? l10n.symptomSheetTitle
          : l10n.symptomSheetEditTitle,
      destructiveAction: widget.existing == null
          ? null
          : DeleteEntryButton(onPressed: _saving ? null : _delete),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _typeId == null || _saving ? null : _save,
          child: Text(l10n.save),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final type in types)
              ChoiceChip(
                label: Text(l10n.symptomTypeLabel(type)),
                selected: _typeId == type.id,
                onSelected: (_) => setState(() => _typeId = type.id),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.intensityLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              l10n.intensityOutOf10(_intensity),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 3,
              label: Text(l10n.intensityMild, overflow: TextOverflow.ellipsis),
            ),
            ButtonSegment(
              value: 5,
              label: Text(
                l10n.intensityModerate,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment(
              value: 8,
              label: Text(
                l10n.intensitySevere,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {3, 5, 8}.contains(_intensity) ? {_intensity} : <int>{},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() => _intensity = selection.first);
            }
          },
        ),
        Slider(
          value: _intensity.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: '$_intensity',
          onChanged: (value) => setState(() => _intensity = value.round()),
        ),
        TextField(
          controller: _duration,
          decoration: InputDecoration(labelText: l10n.durationLabel),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
