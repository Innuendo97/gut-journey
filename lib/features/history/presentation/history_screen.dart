import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/domain/tracker_kind.dart';
import 'package:gut_journey/features/diary/presentation/diary_day_body.dart';
import 'package:gut_journey/features/history/presentation/history_providers.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/// Day-centric history: a prominent day header with ◀ ▶ stepping and an
/// on-demand month calendar, above the same editable day view as Today.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(historySelectedDayProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabHistory)),
      body: Column(
        children: [
          _DayHeader(selected: selected),
          const Divider(height: 1),
          Expanded(child: DiaryDayBody(day: selected)),
        ],
      ),
    );
  }
}

/// The spine of the diary: which day am I looking at, and how do I move.
class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.selected});

  final LocalDay selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
    final notifier = ref.read(historySelectedDayProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.historyPreviousDay,
            onPressed: notifier.previousDay,
          ),
          Expanded(
            child: Text(
              _dayTitle(context, selected, today),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.historyNextDay,
            onPressed: selected.isBefore(today) ? notifier.nextDay : null,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n.historyOpenCalendar,
            onPressed: () => unawaited(_openCalendarSheet(context)),
          ),
        ],
      ),
    );
  }

  String _dayTitle(BuildContext context, LocalDay day, LocalDay today) {
    final l10n = AppLocalizations.of(context);
    if (day == today) return l10n.todayLabel;
    if (day == today.previous) return l10n.yesterdayLabel;
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMMMEEEEd(locale).format(day.toDateTime());
  }

  Future<void> _openCalendarSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CalendarSheet(initialDay: selected),
    );
  }
}

/// Month calendar in a bottom sheet; picking a day selects it and closes.
class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet({required this.initialDay});

  final LocalDay initialDay;

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _focusedMonth = widget.initialDay.toDateTime();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetCalendar(
            focusedMonth: _focusedMonth,
            onPageChanged: (focusedDay) =>
                setState(() => _focusedMonth = focusedDay),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetCalendar extends ConsumerWidget {
  const _SheetCalendar({
    required this.focusedMonth,
    required this.onPageChanged,
  });

  final DateTime focusedMonth;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
    final selected = ref.watch(historySelectedDayProvider);
    final monthKey =
        '${focusedMonth.year.toString().padLeft(4, '0')}-'
        '${focusedMonth.month.toString().padLeft(2, '0')}';
    final markers =
        ref.watch(historyMarkersProvider(monthKey)).value ?? const {};

    return TableCalendar<TrackerKind>(
      locale: Localizations.localeOf(context).toString(),
      firstDay: DateTime(2020),
      lastDay: today.toDateTime(),
      focusedDay: focusedMonth,
      selectedDayPredicate: (day) => LocalDay.fromDateTime(day) == selected,
      eventLoader: (day) =>
          markers[LocalDay.fromDateTime(day)]?.toList() ?? const [],
      startingDayOfWeek: StartingDayOfWeek.monday,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(markerBuilder: _buildDayMarkers),
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
        Navigator.of(context).pop();
      },
      onPageChanged: onPageChanged,
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
