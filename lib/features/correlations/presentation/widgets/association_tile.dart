import 'package:flutter/material.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/features/correlations/domain/correlation_models.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// One observed association with its raw counts on both sides of the
/// comparison — the numbers always travel with the claim.
class AssociationTile extends StatelessWidget {
  const AssociationTile({
    required this.association,
    required this.symptomLabel,
    super.key,
  });

  final FoodSymptomAssociation association;

  /// Resolved by the caller (presentation owns symptom-type labels).
  final String symptomLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a = association;
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.correlationsPair(symptomLabel, a.foodName),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                StrengthChip(strength: a.strength),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.correlationsExposedCounts(
                a.foodName,
                a.exposedWithSymptom,
                a.exposedMeals,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              l10n.correlationsBaselineCounts(
                a.baselineWithSymptom,
                a.baselineMeals,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              switch (a.lift) {
                final lift? => l10n.correlationsLift(lift.toStringAsFixed(1)),
                null => l10n.correlationsNoBaseline,
              },
              style: captionStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact signal-strength badge; emphasis grows with the bucket without
/// ever reaching for alarm colors.
class StrengthChip extends StatelessWidget {
  const StrengthChip({required this.strength, super.key});

  final CorrelationStrength strength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (strength) {
      CorrelationStrength.weak => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
      ),
      CorrelationStrength.moderate => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      CorrelationStrength.strong => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l10n.correlationStrengthLabel(strength),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
