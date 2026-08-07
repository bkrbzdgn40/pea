import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_migration_policy.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_evaluation_origin.dart';

void main() {
  final policy = ChallengeMedalMigrationPolicy(
    firstEligibleDailyKey: '2026-08-07',
    firstEligibleWeeklyKey: '2026-08-10',
    firstEligibleMonthlyKey: '2026-09',
  );

  test('allows live and reconciliation only from configured period keys', () {
    expect(
      policy.allows(
        window: _window(ChallengePeriod.daily, DateTime.utc(2026, 8, 7)),
        origin: RewardEvaluationOrigin.live,
      ),
      isTrue,
    );
    expect(
      policy.allows(
        window: _window(ChallengePeriod.weekly, DateTime.utc(2026, 8, 9)),
        origin: RewardEvaluationOrigin.reconciliation,
      ),
      isFalse,
    );
  });

  test('never allows historical medal backfill', () {
    expect(
      policy.allows(
        window: _window(ChallengePeriod.monthly, DateTime.utc(2026, 9, 12)),
        origin: RewardEvaluationOrigin.historicalBackfill,
      ),
      isFalse,
    );
  });

  test('requires the weekly rollout key to be a Monday', () {
    expect(
      () => ChallengeMedalMigrationPolicy(
        firstEligibleDailyKey: '2026-08-07',
        firstEligibleWeeklyKey: '2026-08-11',
        firstEligibleMonthlyKey: '2026-09',
      ),
      throwsArgumentError,
    );
  });
}

ChallengePeriodWindow _window(ChallengePeriod period, DateTime instant) {
  return ChallengePeriodWindow.forInstant(
    period: period,
    instant: instant,
    timezoneOffset: Duration.zero,
  );
}
