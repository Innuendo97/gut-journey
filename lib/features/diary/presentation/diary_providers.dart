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

final activeMedicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchAll(activeOnly: true),
);
