import 'package:gut_journey/core/domain/local_day.dart';
import 'package:meta/meta.dart';

/// An inclusive range of diary days — the period statistics are computed
/// over. Value-equal so it can key provider families.
@immutable
class DateRange {
  DateRange(this.start, this.end)
    : assert(!start.isAfter(end), 'start must not be after end');

  /// The [days] most recent days ending on [endingOn] (inclusive).
  factory DateRange.lastDays(int days, {required LocalDay endingOn}) =>
      DateRange(endingOn.addDays(-(days - 1)), endingOn);

  final LocalDay start;
  final LocalDay end;

  int get lengthInDays =>
      end.toDateTime().difference(start.toDateTime()).inDays + 1;

  /// Every day in the range, in order.
  List<LocalDay> get days => [
    for (var day = start; !day.isAfter(end); day = day.next) day,
  ];

  bool contains(LocalDay day) => !day.isBefore(start) && !day.isAfter(end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start..$end';
}
