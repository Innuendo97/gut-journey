import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';
import 'package:gut_journey/features/fodmap/domain/fodmap_group.dart';

part 'fodmap_challenge.freezed.dart';
part 'fodmap_challenge.g.dart';

/// Where a reintroduction test stands. Stored by name — never rename.
enum ChallengeStatus { testing, washout, completed, abandoned }

/// What the user observed during the test window — deliberately
/// descriptive, never a tolerance verdict. Stored by name — never rename.
enum ObservedOutcome { noSymptoms, someSymptoms, markedSymptoms }

/// One reintroduction test of a FODMAP group: a test phase logged in the
/// diary, an optional washout, and the outcome as observed by the user.
@freezed
abstract class FodmapChallenge with _$FodmapChallenge {
  const factory FodmapChallenge({
    required String id,
    required FodmapGroup group,
    required ChallengeStatus status,
    required LocalDay startDay,
    LocalDay? testEndDay,
    LocalDay? completedDay,
    ObservedOutcome? outcome,
    String? outcomeNote,
  }) = _FodmapChallenge;

  factory FodmapChallenge.fromJson(Map<String, dynamic> json) =>
      _$FodmapChallengeFromJson(json);
}
