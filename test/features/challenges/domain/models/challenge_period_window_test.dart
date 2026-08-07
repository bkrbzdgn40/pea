import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';

void main() {
  group('ChallengePeriodWindow', () {
    const istanbulOffset = Duration(hours: 3);
    final instant = DateTime.utc(2026, 8, 6, 21, 30);

    test('builds a stable local daily key and UTC boundaries', () {
      final window = ChallengePeriodWindow.forInstant(
        period: ChallengePeriod.daily,
        instant: instant,
        timezoneOffset: istanbulOffset,
      );

      expect(window.key, '2026-08-07');
      expect(window.wallClockStart, DateTime.utc(2026, 8, 7));
      expect(window.utcStart, DateTime.utc(2026, 8, 6, 21));
      expect(window.utcEndExclusive, DateTime.utc(2026, 8, 7, 21));
      expect(window.timezoneOffsetMinutes, 180);
      expect(window.contains(DateTime.utc(2026, 8, 7, 20, 59)), isTrue);
      expect(window.contains(DateTime.utc(2026, 8, 7, 21)), isFalse);
    });

    test('weekly periods start on Monday and cross year boundaries', () {
      final window = ChallengePeriodWindow.forInstant(
        period: ChallengePeriod.weekly,
        instant: DateTime.utc(2027, 1, 1, 12),
        timezoneOffset: Duration.zero,
      );

      expect(window.key, '2026-12-28');
      expect(window.wallClockStart.weekday, DateTime.monday);
      expect(window.wallClockEndExclusive, DateTime.utc(2027, 1, 4));
    });

    test('monthly periods use calendar month boundaries', () {
      final window = ChallengePeriodWindow.forInstant(
        period: ChallengePeriod.monthly,
        instant: DateTime.utc(2026, 12, 31, 23, 30),
        timezoneOffset: const Duration(hours: 2),
      );

      expect(window.key, '2027-01');
      expect(window.wallClockStart, DateTime.utc(2027, 1));
      expect(window.wallClockEndExclusive, DateTime.utc(2027, 2));
      expect(window.utcStart, DateTime.utc(2026, 12, 31, 22));
    });

    test('rejects impossible or sub-minute timezone offsets', () {
      expect(
        () => ChallengePeriodWindow.forInstant(
          period: ChallengePeriod.daily,
          instant: instant,
          timezoneOffset: const Duration(hours: 15),
        ),
        throwsArgumentError,
      );
      expect(
        () => ChallengePeriodWindow.forInstant(
          period: ChallengePeriod.daily,
          instant: instant,
          timezoneOffset: const Duration(seconds: 30),
        ),
        throwsArgumentError,
      );
    });
  });
}
