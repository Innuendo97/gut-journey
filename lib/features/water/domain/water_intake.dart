import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gut_journey/core/domain/local_day.dart';

part 'water_intake.freezed.dart';
part 'water_intake.g.dart';

/// A drink of water. Multiple entries per day are summed against the daily
/// goal from settings.
@freezed
abstract class WaterIntake with _$WaterIntake {
  const factory WaterIntake({
    required String id,
    required int amountMl,
    required DateTime occurredAt,
    required LocalDay day,
    String? notes,
  }) = _WaterIntake;

  factory WaterIntake.fromJson(Map<String, dynamic> json) =>
      _$WaterIntakeFromJson(json);
}
