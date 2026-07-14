import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';

part 'weight_entry.freezed.dart';
part 'weight_entry.g.dart';

/// A body-weight measurement, always metric in the domain (unit conversion
/// is a presentation concern).
@freezed
abstract class WeightEntry with _$WeightEntry {
  const factory WeightEntry({
    required String id,
    required double weightKg,
    required DateTime occurredAt,
    required LocalDay day,
    String? notes,
  }) = _WeightEntry;

  factory WeightEntry.fromJson(Map<String, dynamic> json) =>
      _$WeightEntryFromJson(json);
}
