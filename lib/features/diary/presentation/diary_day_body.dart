import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/widgets/empty_state.dart';
import 'package:gut_journey/features/diary/presentation/diary_providers.dart';
import 'package:gut_journey/features/diary/presentation/entry_timeline.dart';
import 'package:gut_journey/features/diary/presentation/today_screen.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// The interactive day view shared by Today and History: quick-add bar,
/// summary strip and the entry timeline. Fully editable, so back-filling a
/// past day from History works exactly like logging today.
class DiaryDayBody extends ConsumerWidget {
  const DiaryDayBody({required this.day, super.key});

  final LocalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diaryAsync = ref.watch(diaryDayProvider(day));

    return Column(
      children: [
        QuickAddBar(day: day),
        Expanded(
          child: switch (diaryAsync) {
            AsyncValue(value: final diaryDay?) => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                DaySummaryStrip(diaryDay: diaryDay),
                if (diaryDay.isEmpty)
                  EmptyState(
                    icon: Icons.edit_calendar_outlined,
                    title: l10n.emptyDayTitle,
                    subtitle: l10n.emptyDaySubtitle,
                  )
                else
                  EntryTimeline(diaryDay: diaryDay),
              ],
            ),
            AsyncValue(:final error?) => Center(child: Text('$error')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}
