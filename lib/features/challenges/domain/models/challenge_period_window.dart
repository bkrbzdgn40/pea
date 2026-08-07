import 'challenge_period.dart';

/// Stable calendar window derived from an event instant and its local offset.
///
/// Wall-clock boundaries are intentionally calculated with the offset captured
/// at the event. That keeps historical period keys stable when the device later
/// changes timezone.
class ChallengePeriodWindow {
  const ChallengePeriodWindow._({
    required this.period,
    required this.key,
    required this.timezoneOffset,
    required this.wallClockStart,
    required this.wallClockEndExclusive,
    required this.utcStart,
    required this.utcEndExclusive,
  });

  factory ChallengePeriodWindow.forInstant({
    required ChallengePeriod period,
    required DateTime instant,
    required Duration timezoneOffset,
  }) {
    validateChallengeTimezoneOffset(timezoneOffset);

    final utcInstant = instant.toUtc();
    final wallClock = utcInstant.add(timezoneOffset);
    final wallDate = DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
    );

    final DateTime wallStart;
    final DateTime wallEnd;
    final String key;

    switch (period) {
      case ChallengePeriod.daily:
        wallStart = wallDate;
        wallEnd = wallStart.add(const Duration(days: 1));
        key = _dateKey(wallStart);
      case ChallengePeriod.weekly:
        wallStart = wallDate.subtract(Duration(days: wallDate.weekday - 1));
        wallEnd = wallStart.add(const Duration(days: 7));
        key = _dateKey(wallStart);
      case ChallengePeriod.monthly:
        wallStart = DateTime.utc(wallDate.year, wallDate.month);
        wallEnd = DateTime.utc(wallDate.year, wallDate.month + 1);
        key = _monthKey(wallStart);
    }

    return ChallengePeriodWindow._(
      period: period,
      key: key,
      timezoneOffset: timezoneOffset,
      wallClockStart: wallStart,
      wallClockEndExclusive: wallEnd,
      utcStart: wallStart.subtract(timezoneOffset),
      utcEndExclusive: wallEnd.subtract(timezoneOffset),
    );
  }

  final ChallengePeriod period;
  final String key;
  final Duration timezoneOffset;

  /// UTC-flagged value whose components represent the captured local clock.
  final DateTime wallClockStart;

  /// UTC-flagged value whose components represent the captured local clock.
  final DateTime wallClockEndExclusive;

  final DateTime utcStart;
  final DateTime utcEndExclusive;

  int get timezoneOffsetMinutes => timezoneOffset.inMinutes;

  String get startLocalDateKey => _dateKey(wallClockStart);
  String get endLocalDateExclusiveKey => _dateKey(wallClockEndExclusive);

  bool contains(DateTime instant) {
    final utc = instant.toUtc();
    return !utc.isBefore(utcStart) && utc.isBefore(utcEndExclusive);
  }
}

void validateChallengeTimezoneOffset(Duration offset) {
  const maximumOffset = Duration(hours: 14);
  if (offset.abs() > maximumOffset || offset.inSeconds % 60 != 0) {
    throw ArgumentError.value(
      offset,
      'timezoneOffset',
      'Timezone offset must be a whole minute between -14:00 and +14:00.',
    );
  }
}

String _dateKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _monthKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}
