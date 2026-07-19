import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';

final diaryDayProvider = StreamProvider.family<DiaryDay, LocalDay>(
  (ref, day) => ref.watch(diaryRepositoryProvider).watchDay(day),
);

final symptomTypesProvider = StreamProvider<List<SymptomType>>(
  (ref) => ref.watch(symptomRepositoryProvider).watchTypes(),
);

/// Every medication, current or past: which ones belong to a given diary
/// day is decided by their date window, not by [Medication.isActive].
final medicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchAll(),
);

/// The medications whose validity window covers the given day — the set the
/// diary offers for logging doses on that day, even when the therapy has
/// since ended or been deactivated.
final medicationsOnDayProvider = Provider.family<List<Medication>, LocalDay>(
  (ref, day) => [
    for (final med
        in ref.watch(medicationsProvider).value ?? const <Medication>[])
      if (med.coversDay(day)) med,
  ],
);
