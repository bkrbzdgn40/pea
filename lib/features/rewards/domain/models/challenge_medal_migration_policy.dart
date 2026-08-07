import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/challenge_period_window.dart';
import '../../../challenges/domain/models/activity_day_summary.dart';
import 'reward_evaluation_origin.dart';

/// Explicit rollout boundary for period medals.
///
/// Historical medal backfill is deliberately disabled. Reconciliation may
/// repair rewards only for periods on or after the configured rollout keys.
class ChallengeMedalMigrationPolicy {
  ChallengeMedalMigrationPolicy({
    required this.firstEligibleDailyKey,
    required this.firstEligibleWeeklyKey,
    required this.firstEligibleMonthlyKey,
  }) {
    if (!isValidActivityLocalDate(firstEligibleDailyKey)) {
      throw ArgumentError.value(
        firstEligibleDailyKey,
        'firstEligibleDailyKey',
        'Expected a real YYYY-MM-DD date.',
      );
    }
    if (!isValidActivityLocalDate(firstEligibleWeeklyKey) ||
        _parseDateKey(firstEligibleWeeklyKey).weekday != DateTime.monday) {
      throw ArgumentError.value(
        firstEligibleWeeklyKey,
        'firstEligibleWeeklyKey',
        'Expected a real Monday in YYYY-MM-DD form.',
      );
    }
    if (!_isValidMonthKey(firstEligibleMonthlyKey)) {
      throw ArgumentError.value(
        firstEligibleMonthlyKey,
        'firstEligibleMonthlyKey',
        'Expected a real YYYY-MM month.',
      );
    }
  }

  final String firstEligibleDailyKey;
  final String firstEligibleWeeklyKey;
  final String firstEligibleMonthlyKey;

  bool allows({
    required ChallengePeriodWindow window,
    required RewardEvaluationOrigin origin,
  }) {
    if (origin == RewardEvaluationOrigin.historicalBackfill) {
      return false;
    }
    return window.key.compareTo(firstEligibleKeyFor(window.period)) >= 0;
  }

  String firstEligibleKeyFor(ChallengePeriod period) {
    return switch (period) {
      ChallengePeriod.daily => firstEligibleDailyKey,
      ChallengePeriod.weekly => firstEligibleWeeklyKey,
      ChallengePeriod.monthly => firstEligibleMonthlyKey,
    };
  }
}

DateTime _parseDateKey(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

bool _isValidMonthKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final parsed = DateTime.utc(year, month);
  return parsed.year == year && parsed.month == month;
}
