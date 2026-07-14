import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';

part 'medication_intake.freezed.dart';
part 'medication_intake.g.dart';

/// A dose the user marked as taken or skipped.
@freezed
abstract class MedicationIntake with _$MedicationIntake {
  const factory MedicationIntake({
    required String id,
    required String medicationId,
    required IntakeStatus status,
    required DateTime occurredAt,
    required LocalDay day,

    /// The "HH:mm" schedule slot this intake fulfils, for scheduled doses.
    String? scheduledTime,
    String? notes,
  }) = _MedicationIntake;

  factory MedicationIntake.fromJson(Map<String, dynamic> json) =>
      _$MedicationIntakeFromJson(json);
}
