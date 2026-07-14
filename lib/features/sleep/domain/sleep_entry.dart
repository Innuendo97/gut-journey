import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';

part 'sleep_entry.freezed.dart';
part 'sleep_entry.g.dart';

/// The night of sleep ending on [day] (the wake-up day) — at most one per
/// day. Bed/wake times are optional; duration is what statistics use.
@freezed
abstract class SleepEntry with _$SleepEntry {
  const factory SleepEntry({
    required String id,
    required LocalDay day,
    required int durationMinutes,
    DateTime? bedAt,
    DateTime? wokeAt,
    int? quality,
    String? notes,
  }) = _SleepEntry;

  factory SleepEntry.fromJson(Map<String, dynamic> json) =>
      _$SleepEntryFromJson(json);
}
