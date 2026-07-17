import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/features/correlations/presentation/correlations_providers.dart';
import 'package:gut_journey/features/correlations/presentation/widgets/association_tile.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/stats/presentation/stats_providers.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Full ranked list of observed food↔symptom associations, with the
/// window selector and an honest explanation of the method.
class CorrelationsScreen extends ConsumerWidget {
  const CorrelationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = ref.watch(statsRangeProvider);
    final period = ref.watch(statsPeriodDaysProvider);
    final window = ref.watch(correlationWindowProvider);
    final result = ref
        .watch(correlationsProvider((range: range, window: window)))
        .value;
    final typesById = {
      for (final type
          in ref.watch(symptomTypesProvider).value ?? const <SymptomType>[])
        type.id: type,
    };
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final hasDiaryData =
        result != null &&
        (result.analyzedMeals > 0 || result.analyzedSymptomEvents > 0);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.correlationsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Center(
            child: Text(
              '${l10n.correlationsWindowLabel} · '
              '${l10n.statsPeriodDays(period)}',
              style: captionStyle,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: SegmentedButton<Duration>(
              segments: [
                for (final option in correlationWindowOptions)
                  ButtonSegment(
                    value: option,
                    label: Text(l10n.correlationsWindowHours(option.inHours)),
                  ),
              ],
              selected: {window},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(correlationWindowProvider.notifier).window =
                      selection.first,
            ),
          ),
          const SizedBox(height: 8),
          if (result == null)
            const SizedBox.shrink()
          else if (!hasDiaryData)
            EmptyState(
              icon: Icons.hub_outlined,
              title: l10n.correlationsEmptyTitle,
              subtitle: l10n.correlationsEmptySubtitle,
            )
          else ...[
            if (result.associations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.correlationsNoPatterns),
              )
            else
              for (final association in result.associations)
                AssociationTile(
                  association: association,
                  symptomLabel: switch (typesById[association.symptomTypeId]) {
                    final type? => l10n.symptomTypeLabel(type),
                    null => association.symptomTypeId,
                  },
                ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                l10n.correlationsAnalyzed(
                  result.analyzedMeals,
                  result.analyzedSymptomEvents,
                ),
                style: captionStyle,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 8),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.correlationsMethodTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.correlationsMethodBody(window.inHours),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.correlationsDisclaimer, style: captionStyle),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
