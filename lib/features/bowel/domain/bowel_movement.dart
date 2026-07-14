import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';

part 'bowel_movement.freezed.dart';
part 'bowel_movement.g.dart';

/// A logged bowel movement, classified on the Bristol Stool Scale (1–7).
@freezed
abstract class BowelMovement with _$BowelMovement {
  const factory BowelMovement({
    required String id,
    required int bristolType,
    required DateTime occurredAt,
    required LocalDay day,
    @Default(false) bool urgency,
    int? pain,
    @Default(false) bool blood,
    @Default(false) bool mucus,
    @Default(false) bool incompleteEvacuation,
    String? notes,
  }) = _BowelMovement;

  factory BowelMovement.fromJson(Map<String, dynamic> json) =>
      _$BowelMovementFromJson(json);
}
