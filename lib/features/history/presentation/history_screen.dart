import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/diary/domain/tracker_kind.dart';
import 'package:gut_journey/features/diary/presentation/diary_day_body.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';

/// The day inspected on the History tab (independent of Today's selection).
final historySelectedDayProvider =
    NotifierProvider<HistorySelectedDayNotifier, LocalDay>(
      HistorySelectedDayNotifier.new,
    );

class HistorySelectedDayNotifier extends Notifier<LocalDay> {
  @override
  LocalDay build() => LocalDay.fromDateTime(ref.watch(clockProvider)());

  LocalDay get day => state;
  set day(LocalDay value) => state = value;
}

/// Tracker markers for the days of one month ("YYYY-MM").
final historyMarkersProvider = StreamProvider.autoDispose
    .family<Map<LocalDay, Set<TrackerKind>>, String>((ref, month) {
      final first = LocalDay('$month-01');
      final last = first.addDays(31 + 6); // pad into adjacent visible weeks
      return ref
          .watch(diaryRepositoryProvider)
          .watchTrackerDays(first.addDays(-7), last);
    });

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _focusedMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
    final selected = ref.watch(historySelectedDayProvider);
    final focused = _focusedMonth ?? selected.toDateTime();
    final monthKey =
        '${focused.year.toString().padLeft(4, '0')}-'
        '${focused.month.toString().padLeft(2, '0')}';
    final markers =
        ref.watch(historyMarkersProvider(monthKey)).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: Column(
        children: [
          TableCalendar<TrackerKind>(
            locale: Localizations.localeOf(context).toString(),
            firstDay: DateTime(2020),
            lastDay: today.toDateTime(),
            focusedDay: focused,
            selectedDayPredicate: (day) =>
                LocalDay.fromDateTime(day) == selected,
            eventLoader: (day) =>
                markers[LocalDay.fromDateTime(day)]?.toList() ?? const [],
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: _buildDayMarkers,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              ref.read(historySelectedDayProvider.notifier).day =
                  LocalDay.fromDateTime(selectedDay);
              setState(() => _focusedMonth = focusedDay);
            },
            onPageChanged: (focusedDay) =>
                setState(() => _focusedMonth = focusedDay),
          ),
          const Divider(height: 1),
          Expanded(child: DiaryDayBody(day: selected)),
        ],
      ),
    );
  }

  /// One small dot per tracker category (fixed order, max four), instead of
  /// the single undifferentiated marker.
  Widget? _buildDayMarkers(
    BuildContext context,
    DateTime day,
    List<TrackerKind> events,
  ) {
    if (events.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    final kinds = events.toSet();
    final colors = <Color>[
      // Nutrition
      if (kinds.contains(TrackerKind.meal) || kinds.contains(TrackerKind.water))
        scheme.primary,
      // Gut signals
      if (kinds.contains(TrackerKind.symptom) ||
          kinds.contains(TrackerKind.bowel))
        scheme.error,
      // Therapy
      if (kinds.contains(TrackerKind.medication)) scheme.tertiary,
      // Body & lifestyle
      if (kinds.contains(TrackerKind.weight) ||
          kinds.contains(TrackerKind.sleep) ||
          kinds.contains(TrackerKind.activity))
        scheme.secondary,
    ];
    return Positioned(
      bottom: 4,
      child: Row(
        key: ValueKey('history-markers-${LocalDay.fromDateTime(day).value}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final color in colors)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
