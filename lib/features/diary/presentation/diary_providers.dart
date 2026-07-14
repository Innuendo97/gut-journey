import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/core/providers/clock_provider.dart';
import 'package:gut_journey/features/diary/data/diary_repository.dart';
import 'package:gut_journey/features/diary/domain/diary_day.dart';
import 'package:gut_journey/features/medications/data/medication_repository.dart';
import 'package:gut_journey/features/medications/domain/medication.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_type.dart';

/// The day shown on the Today tab. History has its own selection.
final selectedDayProvider = NotifierProvider<SelectedDayNotifier, LocalDay>(
  SelectedDayNotifier.new,
);

class SelectedDayNotifier extends Notifier<LocalDay> {
  @override
  LocalDay build() => LocalDay.fromDateTime(ref.watch(clockProvider)());

  void previousDay() => state = state.previous;

  /// Moves forward, never past today.
  void nextDay() {
    final today = LocalDay.fromDateTime(ref.read(clockProvider)());
    if (state.isBefore(today)) state = state.next;
  }

  void goToToday() => state = LocalDay.fromDateTime(ref.read(clockProvider)());
}

final diaryDayProvider = StreamProvider.family<DiaryDay, LocalDay>(
  (ref, day) => ref.watch(diaryRepositoryProvider).watchDay(day),
);

final symptomTypesProvider = StreamProvider<List<SymptomType>>(
  (ref) => ref.watch(symptomRepositoryProvider).watchTypes(),
);

final activeMedicationsProvider = StreamProvider<List<Medication>>(
  (ref) => ref.watch(medicationRepositoryProvider).watchAll(activeOnly: true),
);
