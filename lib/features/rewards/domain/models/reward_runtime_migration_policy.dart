import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/challenge_period_window.dart';
import 'challenge_medal_migration_policy.dart';

/// V1 rollout boundaries for runtime reward generation.
///
/// Progress starts on the launch date. Weekly/monthly medals may use the
/// containing calendar period, but pre-launch sessions are never inserted into
/// activity aggregates, so only post-launch work contributes.
class RewardRuntimeMigrationPolicy {
  const RewardRuntimeMigrationPolicy({
    this.launchLocalDate = '2026-08-07',
    this.firstEligibleWeeklyKey = '2026-08-03',
    this.firstEligibleMonthlyKey = '2026-08',
  });

  final String launchLocalDate;
  final String firstEligibleWeeklyKey;
  final String firstEligibleMonthlyKey;

  ChallengeMedalMigrationPolicy get challengeMedalPolicy =>
      ChallengeMedalMigrationPolicy(
        firstEligibleDailyKey: launchLocalDate,
        firstEligibleWeeklyKey: firstEligibleWeeklyKey,
        firstEligibleMonthlyKey: firstEligibleMonthlyKey,
      );

  bool allowsProgress({
    required DateTime instant,
    required Duration timezoneOffset,
  }) {
    final window = ChallengePeriodWindow.forInstant(
      period: ChallengePeriod.daily,
      instant: instant,
      timezoneOffset: timezoneOffset,
    );
    return window.key.compareTo(launchLocalDate) >= 0;
  }
}
