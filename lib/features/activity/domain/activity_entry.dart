import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/activity/domain/effort.dart';

part 'activity_entry.freezed.dart';
part 'activity_entry.g.dart';

/// A physical-activity session.
@freezed
abstract class ActivityEntry with _$ActivityEntry {
  const factory ActivityEntry({
    required String id,
    required String name,
    required int durationMinutes,
    required Effort effort,
    required DateTime occurredAt,
    required LocalDay day,
    String? notes,
  }) = _ActivityEntry;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) =>
      _$ActivityEntryFromJson(json);
}
