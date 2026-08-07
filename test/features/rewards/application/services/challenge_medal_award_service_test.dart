import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/challenges/infrastructure/repositories/firestore_challenge_progress_repository.dart';
import 'package:pose_estimation_app/features/rewards/application/services/challenge_medal_award_service.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_migration_policy.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_evaluation_origin.dart';
import 'package:pose_estimation_app/features/rewards/infrastructure/repositories/firestore_reward_ledger_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('ChallengeMedalAwardService', () {
    late FirestoreChallengeProgressRepository progressRepository;
    late ChallengeMedalAwardService service;

    setUp(() {
      final firestore = FakeFirebaseFirestore();
      progressRepository = FirestoreChallengeProgressRepository(firestore);
      service = ChallengeMedalAwardService(
        progressRepository: progressRepository,
        rewardRepository: FirestoreRewardLedgerRepository(firestore),
        migrationPolicy: ChallengeMedalMigrationPolicy(
          firstEligibleDailyKey: '2026-08-07',
          firstEligibleWeeklyKey: '2026-08-10',
          firstEligibleMonthlyKey: '2026-09',
        ),
      );
    });

    test(
      'creates bronze, upgrades silver, and ignores repeated evaluation',
      () async {
        final firstAt = DateTime.utc(2026, 8, 7, 8);
        await _addPushUps(
          progressRepository,
          sessionId: 'session-1',
          value: 10,
          endedAt: firstAt,
        );
        final bronze = await service.evaluatePeriod(
          ownerId: 'user-1',
          exerciseType: ExerciseType.pushUp,
          period: ChallengePeriod.daily,
          qualifyingEventAt: firstAt,
          timezoneOffset: Duration.zero,
          qualifyingEventId: 'session-1',
          origin: RewardEvaluationOrigin.live,
          now: firstAt,
        );

        final secondAt = firstAt.add(const Duration(hours: 2));
        await _addPushUps(
          progressRepository,
          sessionId: 'session-2',
          value: 10,
          endedAt: secondAt,
        );
        final silver = await service.evaluatePeriod(
          ownerId: 'user-1',
          exerciseType: ExerciseType.pushUp,
          period: ChallengePeriod.daily,
          qualifyingEventAt: secondAt,
          timezoneOffset: Duration.zero,
          qualifyingEventId: 'session-2',
          origin: RewardEvaluationOrigin.live,
          now: secondAt,
        );
        final duplicate = await service.evaluatePeriod(
          ownerId: 'user-1',
          exerciseType: ExerciseType.pushUp,
          period: ChallengePeriod.daily,
          qualifyingEventAt: secondAt,
          timezoneOffset: Duration.zero,
          qualifyingEventId: 'session-2',
          origin: RewardEvaluationOrigin.reconciliation,
          now: secondAt.add(const Duration(minutes: 1)),
        );

        expect(bronze.status, ChallengeMedalAwardStatus.created);
        expect(bronze.reward?.highestTier, MedalTier.bronze);
        expect(silver.status, ChallengeMedalAwardStatus.upgraded);
        expect(silver.reward?.highestTier, MedalTier.silver);
        expect(duplicate.status, ChallengeMedalAwardStatus.unchanged);
      },
    );

    test('does not persist progress below bronze', () async {
      final endedAt = DateTime.utc(2026, 8, 7, 8);
      await _addPushUps(
        progressRepository,
        sessionId: 'session-1',
        value: 9,
        endedAt: endedAt,
      );

      final result = await service.evaluatePeriod(
        ownerId: 'user-1',
        exerciseType: ExerciseType.pushUp,
        period: ChallengePeriod.daily,
        qualifyingEventAt: endedAt,
        timezoneOffset: Duration.zero,
        qualifyingEventId: 'session-1',
        origin: RewardEvaluationOrigin.live,
        now: endedAt,
      );

      expect(result.status, ChallengeMedalAwardStatus.belowBronze);
      expect(result.progressValue, 9);
      expect(result.reward, isNull);
    });

    test(
      'blocks pre-rollout periods and all historical medal backfill',
      () async {
        final beforeRollout = await service.evaluatePeriod(
          ownerId: 'user-1',
          exerciseType: ExerciseType.pushUp,
          period: ChallengePeriod.daily,
          qualifyingEventAt: DateTime.utc(2026, 8, 6, 8),
          timezoneOffset: Duration.zero,
          qualifyingEventId: 'session-old',
          origin: RewardEvaluationOrigin.reconciliation,
          now: DateTime.utc(2026, 8, 7),
        );
        final backfill = await service.evaluatePeriod(
          ownerId: 'user-1',
          exerciseType: ExerciseType.pushUp,
          period: ChallengePeriod.daily,
          qualifyingEventAt: DateTime.utc(2026, 8, 7, 8),
          timezoneOffset: Duration.zero,
          qualifyingEventId: 'session-1',
          origin: RewardEvaluationOrigin.historicalBackfill,
          now: DateTime.utc(2026, 8, 7, 9),
        );

        expect(
          beforeRollout.status,
          ChallengeMedalAwardStatus.blockedByMigrationPolicy,
        );
        expect(
          backfill.status,
          ChallengeMedalAwardStatus.blockedByMigrationPolicy,
        );
      },
    );
  });
}

Future<void> _addPushUps(
  FirestoreChallengeProgressRepository repository, {
  required String sessionId,
  required int value,
  required DateTime endedAt,
}) async {
  await repository.upsertContribution(
    ownerId: 'user-1',
    contribution: ChallengeContribution(
      sessionId: sessionId,
      challengeId: 'push_up_volume',
      catalogVersion: 1,
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      evidenceQuality: ChallengeEvidenceQuality.high,
      value: value.toDouble(),
      endedAt: endedAt,
      timezoneOffset: Duration.zero,
    ),
    now: endedAt,
  );
}
