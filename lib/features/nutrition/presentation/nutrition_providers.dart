import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/nutrition/data/nutrition_repository.dart';
import 'package:gut_journey/features/stats/domain/daily_value.dart';

/// foodItemId → displayable kcal estimate (library subtitles).
final kcalByFoodProvider =
    StreamProvider.autoDispose<Map<String, KcalEstimate>>(
      (ref) => ref.watch(nutritionRepositoryProvider).watchKcalByFood(),
    );

/// Estimated kcal of one day, null when nothing kcal-bearing was logged.
final dayKcalProvider = StreamProvider.autoDispose.family<double?, LocalDay>(
  (ref, day) => ref.watch(nutritionRepositoryProvider).watchDayKcal(day),
);

/// Estimated kcal per day over a range (the Stats chart series).
final kcalStatsProvider = StreamProvider.autoDispose
    .family<List<DailyValue>, DateRange>(
      (ref, range) =>
          ref.watch(nutritionRepositoryProvider).watchKcalDaily(range),
    );
