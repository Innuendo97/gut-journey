import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/features/correlations/presentation/correlations_providers.dart';
import 'package:gut_journey/features/correlations/presentation/widgets/association_tile.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/stats/presentation/stats_providers.dart';
import 'package:gut_journey/features/stats/presentation/widgets/chart_section.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Stats-screen teaser: the top observed associations for the current
/// period at the default window, linking to the full screen.
class ObservedPatternsCard extends ConsumerWidget {
  const ObservedPatternsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = ref.watch(statsRangeProvider);
    final result = ref
        .watch(
          correlationsProvider((
            range: range,
            window: defaultCorrelationWindow,
          )),
        )
        .value;
    final associations = result?.associations ?? const [];
    final typesById = {
      for (final type
          in ref.watch(symptomTypesProvider).value ?? const <SymptomType>[])
        type.id: type,
    };

    return ChartSection(
      title: l10n.correlationsTitle,
      annotation: associations.isEmpty ? null : l10n.correlationsDisclaimer,
      isEmpty: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (associations.isEmpty)
            Text(
              l10n.correlationsCardEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final association in associations.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.correlationsPair(
                          switch (typesById[association.symptomTypeId]) {
                            final type? => l10n.symptomTypeLabel(type),
                            null => association.symptomTypeId,
                          },
                          association.foodName,
                        ),
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StrengthChip(strength: association.strength),
                  ],
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.statsCorrelations),
              child: Text(l10n.correlationsCardSeeAll),
            ),
          ),
        ],
      ),
    );
  }
}
