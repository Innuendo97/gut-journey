import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/medications/domain/medication_enums.dart';
import 'package:gut_journey/features/medications/domain/medication_intake.dart';

/// Adherence of one medication over a day range: how many scheduled doses
/// were expected and how many were marked taken.
///
/// As-needed medications have no expectation, so their adherence is null.
class AdherenceSummary {
  const AdherenceSummary({
    required this.expectedDoses,
    required this.takenDoses,
  });

  final int expectedDoses;
  final int takenDoses;

  /// 0..1, or null when nothing was expected (as-needed medication).
  double? get ratio => expectedDoses == 0 ? null : takenDoses / expectedDoses;
}

/// Computes adherence for [medication] between [from] and [to] (inclusive).
///
/// Taken doses are capped at the expected count per day so extra as-needed
/// style intakes of a scheduled medication can't push adherence above 100%.
AdherenceSummary computeAdherence({
  required Medication medication,
  required List<MedicationIntake> intakes,
  required LocalDay from,
  required LocalDay to,
}) {
  var expected = 0;
  var taken = 0;
  final takenByDay = <String, int>{};
  for (final intake in intakes) {
    if (intake.medicationId != medication.id) continue;
    if (intake.status != IntakeStatus.taken) continue;
    if (intake.day.isBefore(from) || intake.day.isAfter(to)) continue;
    takenByDay[intake.day.value] = (takenByDay[intake.day.value] ?? 0) + 1;
  }
  for (var day = from; !day.isAfter(to); day = day.next) {
    final slots = medication.expectedSlotsOn(day).length;
    expected += slots;
    final takenToday = takenByDay[day.value] ?? 0;
    taken += takenToday > slots ? slots : takenToday;
  }
  return AdherenceSummary(expectedDoses: expected, takenDoses: taken);
}
