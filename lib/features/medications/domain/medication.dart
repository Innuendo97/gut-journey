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
    @Default(false) bool remindersEnabled,
    String? notes,
  }) = _Medication;

  const Medication._();

  factory Medication.fromJson(Map<String, dynamic> json) =>
      _$MedicationFromJson(json);

  /// Whether [day] falls inside this medication's start/end window.
  ///
  /// The window — not [isActive] — decides what belongs to a diary day, so
  /// past days keep their therapy even after it ends. [isActive] only marks
  /// the medication as part of the current therapy (reminders, manage list).
  bool coversDay(LocalDay day) {
    if (day.isBefore(startDay)) return false;
    final end = endDay;
    return end == null || !day.isAfter(end);
  }

  /// The "HH:mm" dose slots expected on [day], empty when the medication is
  /// as-needed or [day] is outside its start/end window.
  List<String> expectedSlotsOn(LocalDay day) {
    if (scheduleType != ScheduleType.daily) return const [];
    return coversDay(day) ? scheduledTimes : const [];
  }
}
