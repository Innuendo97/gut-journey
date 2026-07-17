import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/sheet_scaffold.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Picks the group to test; the challenge starts today.
Future<void> showFodmapChallengeSheet(BuildContext context) {
  return showQuickAddSheet(
    context: context,
    builder: (context) => const FodmapChallengeSheet(),
  );
}

class FodmapChallengeSheet extends ConsumerStatefulWidget {
  const FodmapChallengeSheet({super.key});

  @override
  ConsumerState<FodmapChallengeSheet> createState() =>
      _FodmapChallengeSheetState();
}

class _FodmapChallengeSheetState extends ConsumerState<FodmapChallengeSheet> {
  FodmapGroup? _group;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetScaffold(
      title: l10n.fodmapStartChallenge,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _group == null ? null : () => _start(_group!),
          child: Text(l10n.save),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in FodmapGroup.values)
              ChoiceChip(
                label: Text(l10n.fodmapGroupLabel(group)),
                selected: _group == group,
                onSelected: (selected) =>
                    setState(() => _group = selected ? group : null),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _start(FodmapGroup group) async {
    final today = LocalDay.fromDateTime(ref.read(clockProvider)());
    await ref
        .read(fodmapRepositoryProvider)
        .startChallenge(group: group, startDay: today);
    if (mounted) Navigator.of(context).pop();
  }
}
