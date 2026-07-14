import 'package:flutter_test/flutter_test.dart';
import 'package:gut_journey/core/domain/local_day.dart';

void main() {
  group('LocalDay', () {
    test('formats from a local DateTime with zero padding', () {
      expect(
        LocalDay.fromDateTime(DateTime(2026, 3, 5, 14, 30)).value,
        '2026-03-05',
      );
    });

    test('buckets by local wall time, not UTC', () {
      // 23:30 UTC is already the next day in any timezone east of UTC, and
      // still the same day west of it — the bucket must follow toLocal().
      final utcMoment = DateTime.utc(2026, 7, 14, 23, 30);
      expect(
        LocalDay.fromDateTime(utcMoment),
        LocalDay.fromDateTime(utcMoment.toLocal()),
      );
    });

    test('an instant just after local midnight belongs to the new day', () {
      expect(
        LocalDay.fromDateTime(DateTime(2026, 1, 1, 0, 30)).value,
        '2026-01-01',
      );
      expect(
        LocalDay.fromDateTime(DateTime(2025, 12, 31, 23, 59)).value,
        '2025-12-31',
      );
    });

    test('rejects malformed values', () {
      expect(() => LocalDay('2026-1-05'), throwsFormatException);
      expect(() => LocalDay('yesterday'), throwsFormatException);
      expect(() => LocalDay('2026-03-05T10:00'), throwsFormatException);
    });

    test('addDays crosses month and year boundaries', () {
      expect(LocalDay('2026-01-31').next.value, '2026-02-01');
      expect(LocalDay('2026-01-01').previous.value, '2025-12-31');
      expect(LocalDay('2026-02-26').addDays(3).value, '2026-03-01');
    });

    test('compares chronologically', () {
      expect(LocalDay('2026-02-01').isAfter(LocalDay('2026-01-31')), isTrue);
      expect(LocalDay('2026-02-01').isBefore(LocalDay('2026-02-02')), isTrue);
      expect(LocalDay('2026-02-01'), LocalDay('2026-02-01'));
    });

    test('round-trips through json', () {
      expect(
        LocalDay.fromJson(LocalDay('2026-07-14').toJson()).value,
        '2026-07-14',
      );
    });
  });
}
