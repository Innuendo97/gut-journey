import 'package:meta/meta.dart';

/// A calendar day in the device's local timezone, the bucket every diary
/// entry is grouped under ("the diary day").
///
/// The day is captured **at write time** from the moment an entry occurred,
/// so entries stay on the day the user experienced them even if the device
/// timezone changes later (travel, DST).
///
/// Encoded as `YYYY-MM-DD`, which sorts chronologically as plain text.
@immutable
class LocalDay implements Comparable<LocalDay> {
  LocalDay(this.value) {
    if (!_format.hasMatch(value)) {
      throw FormatException('Not a YYYY-MM-DD day: $value');
    }
  }

  /// The day [moment] falls on in the device's local timezone.
  factory LocalDay.fromDateTime(DateTime moment) {
    final local = moment.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return LocalDay('$y-$m-$d');
  }

  factory LocalDay.fromJson(String json) => LocalDay(json);

  static final _format = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final String value;

  /// Midnight at the start of this day, in local time.
  DateTime toDateTime() {
    final parts = value.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  LocalDay addDays(int days) {
    final midday = toDateTime().add(Duration(days: days, hours: 12));
    return LocalDay.fromDateTime(midday);
  }

  LocalDay get next => addDays(1);
  LocalDay get previous => addDays(-1);

  bool isAfter(LocalDay other) => value.compareTo(other.value) > 0;
  bool isBefore(LocalDay other) => value.compareTo(other.value) < 0;

  String toJson() => value;

  @override
  int compareTo(LocalDay other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is LocalDay && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
