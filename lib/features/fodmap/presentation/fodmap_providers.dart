import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gut_journey/core/domain/date_range.dart';
import 'package:gut_journey/features/fodmap/data/fodmap_repository.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_challenge.dart';
import 'package:gut_journey/features/meals/data/food_repository.dart';
import 'package:gut_journey/features/symptoms/data/symptom_repository.dart';
import 'package:gut_journey/features/symptoms/domain/symptom_entry.dart';

/// `food_attributes` namespace of this feature: `(fodmap, group)` →
/// a `FodmapGroup` name.
const fodmapAttributeSource = 'fodmap';
const fodmapAttributeKey = 'group';

final fodmapChallengesProvider =
    StreamProvider.autoDispose<List<FodmapChallenge>>(
      (ref) => ref.watch(fodmapRepositoryProvider).watchChallenges(),
    );

final activeFodmapChallengeProvider =
    StreamProvider.autoDispose<FodmapChallenge?>(
      (ref) => ref.watch(fodmapRepositoryProvider).watchActiveChallenge(),
    );

/// foodItemId → stored `FodmapGroup` name for the whole library.
final fodmapGroupByFoodProvider =
    StreamProvider.autoDispose<Map<String, String>>(
      (ref) => ref
          .watch(foodRepositoryProvider)
          .watchAttributeValues(
            source: fodmapAttributeSource,
            key: fodmapAttributeKey,
          ),
    );

/// Diary symptoms inside a challenge's test window (outcome sheet).
final fodmapTestSymptomsProvider = StreamProvider.autoDispose
    .family<List<SymptomEntry>, DateRange>(
      (ref, range) => ref.watch(symptomRepositoryProvider).watchByRange(range),
    );
