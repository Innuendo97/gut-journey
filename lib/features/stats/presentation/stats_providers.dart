import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/medications/domain/adherence.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/stats/data/stats_repository.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';

/// The selected statistics period, in days (7 / 30 / 90).
final statsPeriodDaysProvider = NotifierProvider<StatsPeriodNotifier, int>(
  StatsPeriodNotifier.new,
);

class StatsPeriodNotifier extends Notifier<int> {
  static const options = [7, 30, 90];

  @override
  int build() => 30;

  int get days => state;
  set days(int value) => state = value;
}

final statsRangeProvider = Provider<DateRange>((ref) {
  final days = ref.watch(statsPeriodDaysProvider);
  final today = LocalDay.fromDateTime(ref.watch(clockProvider)());
  return DateRange.lastDays(days, endingOn: today);
});

final symptomIntensityStatsProvider = StreamProvider.autoDispose
    .family<Map<String, List<DailyValue>>, DateRange>(
      (ref, range) =>
          ref.watch(statsRepositoryProvider).watchSymptomIntensity(range),
    );

final symptomFrequencyStatsProvider = StreamProvider.autoDispose
    .family<Map<String, int>, DateRange>(
      (ref, range) =>
          ref.watch(statsRepositoryProvider).watchSymptomFrequency(range),
    );

final bristolDistributionStatsProvider = StreamProvider.autoDispose
    .family<Map<int, int>, DateRange>(
      (ref, range) =>
          ref.watch(statsRepositoryProvider).watchBristolDistribution(range),
    );

final weightStatsProvider = StreamProvider.autoDispose
    .family<List<DailyValue>, DateRange>(
      (ref, range) =>
          ref.watch(statsRepositoryProvider).watchWeightDaily(range),
    );

final waterStatsProvider = StreamProvider.autoDispose
    .family<List<DailyValue>, DateRange>(
      (ref, range) => ref.watch(statsRepositoryProvider).watchWaterDaily(range),
    );

final sleepStatsProvider = StreamProvider.autoDispose
    .family<List<DailyValue>, DateRange>(
      (ref, range) => ref.watch(statsRepositoryProvider).watchSleepDaily(range),
    );

final activityStatsProvider = StreamProvider.autoDispose
    .family<List<DailyValue>, DateRange>(
      (ref, range) =>
          ref.watch(statsRepositoryProvider).watchActivityDaily(range),
    );

final adherenceStatsProvider = StreamProvider.autoDispose
    .family<List<(Medication, AdherenceSummary)>, DateRange>(
      (ref, range) => ref.watch(statsRepositoryProvider).watchAdherence(range),
    );
