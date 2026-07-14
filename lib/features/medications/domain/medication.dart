import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

part 'medication.freezed.dart';
part 'medication.g.dart';

/// A medication or supplement in the user's therapy.
@freezed
abstract class Medication with _$Medication {
  const factory Medication({
    required String id,
    required String name,
    required ScheduleType scheduleType,
    required LocalDay startDay,

    /// "HH:mm" times for [ScheduleType.daily]; empty for as-needed.
    @Default(<String>[]) List<String> scheduledTimes,
    String? dosage,
    LocalDay? endDay,
    @Default(true) bool isActive,
    String? notes,
  }) = _Medication;

  const Medication._();

  factory Medication.fromJson(Map<String, dynamic> json) =>
      _$MedicationFromJson(json);

  /// The "HH:mm" dose slots expected on [day], empty when the medication is
  /// as-needed, inactive, or [day] is outside its start/end window.
  List<String> expectedSlotsOn(LocalDay day) {
    if (scheduleType != ScheduleType.daily || !isActive) return const [];
    if (day.isBefore(startDay)) return const [];
    final end = endDay;
    if (end != null && day.isAfter(end)) return const [];
    return scheduledTimes;
  }
}
