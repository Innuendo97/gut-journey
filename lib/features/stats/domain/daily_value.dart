import 'package:gut_journey/core/domain/local_day.dart';
import 'package:meta/meta.dart';

/// One aggregated value for one diary day — the unit every stats series is
/// made of.
@immutable
class DailyValue {
  const DailyValue(this.day, this.value);

  final LocalDay day;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is DailyValue && other.day == day && other.value == value;

  @override
  int get hashCode => Object.hash(day, value);

  @override
  String toString() => '($day: $value)';
}
