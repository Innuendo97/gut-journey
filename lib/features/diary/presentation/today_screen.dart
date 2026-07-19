import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/activity/presentation/activity_quick_add_sheet.dart';
import 'package:gut_journey/features/bowel/presentation/bowel_quick_add_sheet.dart';
import 'package:gut_journey/features/diary/presentation/diary_day_body.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/meals/presentation/meal_quick_add_sheet.dart';
import 'package:gut_journey/features/medications/presentation/medication_quick_add_sheet.dart';
import 'package:gut_journey/features/sleep/presentation/sleep_quick_add_sheet.dart';
import 'package:gut_journey/features/symptoms/presentation/symptom_quick_add_sheet.dart';
import 'package:gut_journey/features/water/data/water_repository.dart';
import 'package:gut_journey/features/weight/presentation/weight_quick_add_sheet.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// The home tab: always pinned to the current day. Past days are reviewed
/// and back-filled from History instead.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final today = LocalDay.fromDateTime(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _GreetingHeader(now: now),
            Expanded(child: DiaryDayBody(day: today)),
          ],
        ),
      ),
    );
  }
}

/// Greeting by time of day plus the full date — Today's replacement for an
/// app bar.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final greeting = switch (now.hour) {
      < 12 => l10n.todayGreetingMorning,
      < 18 => l10n.todayGreetingAfternoon,
      _ => l10n.todayGreetingEvening,
    };
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.yMMMMEEEEd(locale).format(now),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The always-visible row of one-tap entry points — the core promise that
/// logging anything takes seconds.
class QuickAddBar extends ConsumerWidget {
  const QuickAddBar({required this.day, super.key});

  final LocalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final buttons = [
      (
        Icons.restaurant_outlined,
        l10n.quickAddMeal,
        () {
          unawaited(MealQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.healing_outlined,
        l10n.quickAddSymptom,
        () {
          unawaited(SymptomQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.wc_outlined,
        l10n.quickAddBowel,
        () {
          unawaited(BowelQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.water_drop_outlined,
        l10n.quickAddWater,
        () {
          unawaited(_addWater(ref));
        },
      ),
      (
        Icons.monitor_weight_outlined,
        l10n.quickAddWeight,
        () {
          unawaited(WeightQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.medication_outlined,
        l10n.quickAddMedication,
        () {
          unawaited(MedicationQuickAddSheet.show(context, day: day));
        },
      ),
      (
        Icons.bedtime_outlined,
        l10n.quickAddSleep,
        () {
          final diaryDay = ref.read(diaryDayProvider(day)).value;
          unawaited(
            SleepQuickAddSheet.show(
              context,
              day: day,
              existing: diaryDay?.sleep,
            ),
          );
        },
      ),
      (
        Icons.directions_run_outlined,
        l10n.quickAddActivity,
        () {
          unawaited(ActivityQuickAddSheet.show(context, day: day));
        },
      ),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: buttons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final (icon, label, onTap) = buttons[index];
          return _QuickAddButton(icon: icon, label: label, onTap: onTap);
        },
      ),
    );
  }

  Future<void> _addWater(WidgetRef ref) {
    final now = ref.read(clockProvider)();
    final occurredAt = LocalDay.fromDateTime(now) == day
        ? now
        : day.toDateTime().add(const Duration(hours: 12));
    return ref
        .read(waterRepositoryProvider)
        .add(amountMl: 250, occurredAt: occurredAt);
  }
}

class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
