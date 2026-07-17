import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_providers.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Closes a challenge: shows what the diary recorded during the test days
/// and asks the user how they'd describe what they observed.
Future<void> showFodmapOutcomeSheet(
  BuildContext context,
  FodmapChallenge challenge,
) {
  return showQuickAddSheet(
    context: context,
    builder: (context) => FodmapOutcomeSheet(challenge: challenge),
  );
}

class FodmapOutcomeSheet extends ConsumerStatefulWidget {
  const FodmapOutcomeSheet({required this.challenge, super.key});

  final FodmapChallenge challenge;

  @override
  ConsumerState<FodmapOutcomeSheet> createState() => _FodmapOutcomeSheetState();
}

class _FodmapOutcomeSheetState extends ConsumerState<FodmapOutcomeSheet> {
  ObservedOutcome? _outcome;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final challenge = widget.challenge;
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
    final testRange = DateRange(
      challenge.startDay,
      challenge.testEndDay ?? today,
    );
    final symptoms =
        ref.watch(fodmapTestSymptomsProvider(testRange)).value ?? const [];
    final typesById = {
      for (final type
          in ref.watch(symptomTypesProvider).value ?? const <SymptomType>[])
        type.id: type,
    };

    // One line per symptom type: occurrences and the worst intensity.
    final byType = <String, (int, int)>{};
    for (final entry in symptoms) {
      final (count, worst) = byType[entry.symptomTypeId] ?? (0, 0);
      byType[entry.symptomTypeId] = (
        count + 1,
        entry.intensity > worst ? entry.intensity : worst,
      );
    }

    return SheetScaffold(
      title: l10n.fodmapRecordOutcome,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _outcome == null ? null : () => _save(_outcome!, today),
          child: Text(l10n.save),
        ),
      ],
      children: [
        Text(l10n.fodmapSymptomsDuringTest, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (byType.isEmpty)
          Text(
            l10n.fodmapNoSymptomsDuringTest,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final MapEntry(key: typeId, value: (count, worst))
              in byType.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    switch (typesById[typeId]) {
                      final type? => l10n.symptomTypeLabel(type),
                      null => typeId,
                    },
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    l10n.fodmapSymptomTimes(count, worst),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final outcome in ObservedOutcome.values)
              ChoiceChip(
                label: Text(l10n.observedOutcomeLabel(outcome)),
                selected: _outcome == outcome,
                onSelected: (selected) =>
                    setState(() => _outcome = selected ? outcome : null),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: InputDecoration(
            labelText: l10n.notesLabel,
            hintText: l10n.notesHint,
          ),
        ),
      ],
    );
  }

  Future<void> _save(ObservedOutcome outcome, LocalDay today) async {
    final note = _note.text.trim();
    await ref
        .read(fodmapRepositoryProvider)
        .completeChallenge(
          widget.challenge.id,
          outcome: outcome,
          completedDay: today,
          note: note.isEmpty ? null : note,
        );
    if (mounted) Navigator.of(context).pop();
  }
}
