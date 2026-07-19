import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/diary/domain/tracker_kind.dart';

/// The day inspected on the History tab (independent of Today, which is
/// always pinned to the current day).
final historySelectedDayProvider =
    NotifierProvider<HistorySelectedDayNotifier, LocalDay>(
      HistorySelectedDayNotifier.new,
    );

class HistorySelectedDayNotifier extends Notifier<LocalDay> {
  @override
  LocalDay build() => LocalDay.fromDateTime(ref.watch(clockProvider)());

  void previousDay() => state = state.previous;

  /// Moves forward, never past today.
  void nextDay() {
    final today = LocalDay.fromDateTime(ref.read(clockProvider)());
    if (state.isBefore(today)) state = state.next;
  }

  void goToToday() => state = LocalDay.fromDateTime(ref.read(clockProvider)());

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
