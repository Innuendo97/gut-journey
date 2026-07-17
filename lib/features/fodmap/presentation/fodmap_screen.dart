import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/l10n/labels.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_challenge_sheet.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_outcome_sheet.dart';
import 'package:gut_journey/features/fodmap/presentation/fodmap_providers.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// The guided reintroduction path: one group under test at a time, the
/// canonical group list with observed outcomes, food tagging and history.
class FodmapScreen extends ConsumerWidget {
  const FodmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final challenges = ref.watch(fodmapChallengesProvider).value;
    final active = ref.watch(activeFodmapChallengeProvider).value;
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Latest recorded outcome per group, for the chips overview.
    final outcomeByGroup = <FodmapGroup, ObservedOutcome>{};
    for (final challenge
        in (challenges ?? const <FodmapChallenge>[]).reversed) {
      if (challenge.outcome case final outcome?) {
        outcomeByGroup[challenge.group] = outcome;
      }
    }
    final history = [
      for (final challenge in challenges ?? const <FodmapChallenge>[])
        if (challenge.status == ChallengeStatus.completed ||
            challenge.status == ChallengeStatus.abandoned)
          challenge,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.fodmapTile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          if (active != null)
            _ActiveChallengeCard(challenge: active, today: today)
          else ...[
            if (challenges != null && challenges.isEmpty)
              EmptyState(
                icon: Icons.science_outlined,
                title: l10n.fodmapEmptyTitle,
                subtitle: l10n.fodmapEmptySubtitle,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.icon(
                onPressed: () => unawaited(showFodmapChallengeSheet(context)),
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(l10n.fodmapStartChallenge),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(l10n.fodmapGroupsToTest, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in FodmapGroup.values)
                Chip(
                  avatar: switch (outcomeByGroup[group]) {
                    ObservedOutcome.noSymptoms => const Icon(
                      Icons.check_circle_outline,
                    ),
                    ObservedOutcome.someSymptoms ||
                    ObservedOutcome.markedSymptoms => const Icon(
                      Icons.error_outline,
                    ),
                    null => null,
                  },
                  label: Text(l10n.fodmapGroupLabel(group)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sell_outlined),
            title: Text(l10n.fodmapTagFoods),
            subtitle: Text(l10n.fodmapTagFoodsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreFodmapFoods),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.fodmapHistoryTitle, style: theme.textTheme.titleSmall),
            for (final challenge in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.fodmapGroupLabel(challenge.group)),
                subtitle: Text(switch (challenge.outcome) {
                  final outcome? => l10n.observedOutcomeLabel(outcome),
                  null => l10n.challengeStatusLabel(challenge.status),
                }),
                trailing: Text(
                  challenge.completedDay?.value ?? challenge.startDay.value,
                  style: captionStyle,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(l10n.fodmapDisclaimer, style: captionStyle),
        ],
      ),
    );
  }
}

class _ActiveChallengeCard extends ConsumerWidget {
  const _ActiveChallengeCard({required this.challenge, required this.today});

  final FodmapChallenge challenge;
  final LocalDay today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dayNumber =
        today.toDateTime().difference(challenge.startDay.toDateTime()).inDays +
        1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.fodmapActiveTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.fodmapGroupLabel(challenge.group),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${l10n.challengeStatusLabel(challenge.status)} · '
                  '${l10n.fodmapActiveDay(dayNumber)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              l10n.fodmapStartedOn(challenge.startDay.value),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (challenge.status == ChallengeStatus.testing)
                  OutlinedButton(
                    onPressed: () => unawaited(
                      ref
                          .read(fodmapRepositoryProvider)
                          .moveToWashout(challenge.id, testEndDay: today),
                    ),
                    child: Text(l10n.fodmapMoveToWashout),
                  ),
                FilledButton.tonal(
                  onPressed: () =>
                      unawaited(showFodmapOutcomeSheet(context, challenge)),
                  child: Text(l10n.fodmapRecordOutcome),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    ref
                        .read(fodmapRepositoryProvider)
                        .abandonChallenge(challenge.id),
                  ),
                  child: Text(l10n.fodmapAbandon),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
