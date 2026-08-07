import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_runtime_migration_policy.dart';

void main() {
  group('RewardRuntimeMigrationPolicy', () {
    const policy = RewardRuntimeMigrationPolicy();

    test('starts progress on the rollout local date', () {
      expect(
        policy.allowsProgress(
          instant: DateTime.utc(2026, 8, 6, 20, 59),
          timezoneOffset: const Duration(hours: 3),
        ),
        isFalse,
      );
      expect(
        policy.allowsProgress(
          instant: DateTime.utc(2026, 8, 6, 21),
          timezoneOffset: const Duration(hours: 3),
        ),
        isTrue,
      );
    });

    test('keeps weekly and monthly rollout keys explicit', () {
      expect(
        policy.challengeMedalPolicy.firstEligibleKeyFor(ChallengePeriod.daily),
        '2026-08-07',
      );
      expect(
        policy.challengeMedalPolicy.firstEligibleKeyFor(ChallengePeriod.weekly),
        '2026-08-03',
      );
      expect(
        policy.challengeMedalPolicy.firstEligibleKeyFor(
          ChallengePeriod.monthly,
        ),
        '2026-08',
      );
    });
  });
}
