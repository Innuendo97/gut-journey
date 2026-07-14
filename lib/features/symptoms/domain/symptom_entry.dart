import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';

part 'symptom_entry.freezed.dart';
part 'symptom_entry.g.dart';

/// A logged symptom occurrence.
@freezed
abstract class SymptomEntry with _$SymptomEntry {
  const factory SymptomEntry({
    required String id,
    required String symptomTypeId,
    required int intensity,
    required DateTime occurredAt,
    required LocalDay day,
    int? durationMinutes,
    String? notes,
  }) = _SymptomEntry;

  factory SymptomEntry.fromJson(Map<String, dynamic> json) =>
      _$SymptomEntryFromJson(json);
}
