import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/challenges/application/repositories/challenge_progress_repository.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/activity_day_summary.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution_record.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_thresholds.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_progress_mutation.dart';
import 'package:pose_estimation_app/features/challenges/presentation/providers/challenge_progress_providers.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/rewards/application/repositories/reward_ledger_repository.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward_mutation.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_reward.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_history_cursor.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_history_page.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_ledger_mutation.dart';
import 'package:pose_estimation_app/features/rewards/presentation/providers/reward_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  test('builds weekly challenge progress from trusted activity days', () async {
    final repository = _MemoryChallengeProgressRepository(
      days: [
        ActivityDaySummary(
          ownerId: 'user-1',
          localDate: '2026-08-06',
          trustedSessionCount: 2,
          highReliabilitySessionCount: 1,
          validRepsByExercise: const <ExerciseType, int>{
            ExerciseType.pushUp: 12,
          },
          holdSecondsByExercise: const <ExerciseType, double>{
            ExerciseType.plank: 40,
          },
          exerciseTypes: const <ExerciseType>{
            ExerciseType.pushUp,
            ExerciseType.plank,
          },
          createdAt: DateTime.utc(2026, 8, 6, 12),
          updatedAt: DateTime.utc(2026, 8, 6, 12),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        challengeProgressRepositoryProvider.overrideWithValue(repository),
        rewardLedgerRepositoryProvider.overrideWithValue(
          _MemoryRewardLedgerRepository(),
        ),
        goalsClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 8, 7, 12),
        ),
        selectedChallengePeriodProvider.overrideWith(
          (ref) => ChallengePeriod.weekly,
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(challengeGoalsProvider.future);

    expect(state.period, ChallengePeriod.weekly);
    expect(state.window.key, '2026-08-03');
    expect(state.progressFor(ExerciseType.pushUp).value, 12);
    expect(state.progressFor(ExerciseType.plank).value, 40);
    expect(state.progresses, hasLength(ExerciseType.values.length));
    expect(repository.lastStart, '2026-08-03');
    expect(repository.lastEnd, '2026-08-10');
  });

  test(
    'keeps a persisted medal visible when live aggregate is lower',
    () async {
      final progressRepository = _MemoryChallengeProgressRepository(
        days: [
          ActivityDaySummary(
            ownerId: 'user-1',
            localDate: '2026-08-07',
            trustedSessionCount: 1,
            highReliabilitySessionCount: 1,
            validRepsByExercise: const <ExerciseType, int>{
              ExerciseType.pushUp: 4,
            },
            holdSecondsByExercise: const <ExerciseType, double>{},
            exerciseTypes: const <ExerciseType>{ExerciseType.pushUp},
            createdAt: DateTime.utc(2026, 8, 7, 10),
            updatedAt: DateTime.utc(2026, 8, 7, 10),
          ),
        ],
      );
      final rewardRepository = _MemoryRewardLedgerRepository(
        rewards: [_dailyPushUpSilverReward()],
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          challengeProgressRepositoryProvider.overrideWithValue(
            progressRepository,
          ),
          rewardLedgerRepositoryProvider.overrideWithValue(rewardRepository),
          goalsClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 7, 12),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(challengeGoalsProvider.future);
      final pushUp = state.viewFor(ExerciseType.pushUp);

      expect(pushUp.progress.value, 4);
      expect(pushUp.effectiveTier, MedalTier.silver);
      expect(pushUp.displayValue, 20);
      expect(pushUp.nextTier, MedalTier.gold);
      expect(pushUp.remainingToNextTier, 10);
    },
  );

  test(
    'uses push-up as a neutral focus before trusted activity exists',
    () async {
      final repository = _MemoryChallengeProgressRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          challengeProgressRepositoryProvider.overrideWithValue(repository),
          rewardLedgerRepositoryProvider.overrideWithValue(
            _MemoryRewardLedgerRepository(),
          ),
          goalsClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 8, 7, 12),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(challengeGoalsProvider.future);

      expect(state.hasTrustedActivity, isFalse);
      expect(
        state.recommendedFocus.progress.definition.exerciseType,
        ExerciseType.pushUp,
      );
      expect(state.nearbyProgresses(excluding: ExerciseType.pushUp), isEmpty);
    },
  );
}

ChallengeMedalReward _dailyPushUpSilverReward() {
  final bronzeAt = DateTime.utc(2026, 8, 7, 9);
  final silverAt = DateTime.utc(2026, 8, 7, 10);
  return ChallengeMedalReward(
    ownerId: 'user-1',
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    period: ChallengePeriod.daily,
    periodKey: '2026-08-07',
    timezoneOffset: Duration.zero,
    highestTier: MedalTier.silver,
    progressValueAtHighestTier: 20,
    thresholdsAtAward: MedalThresholds(bronze: 10, silver: 20, gold: 30),
    tierEarnedAt: <MedalTier, DateTime>{
      MedalTier.bronze: bronzeAt,
      MedalTier.silver: silverAt,
    },
    qualifyingEventId: 'session-20',
    isBackfilled: false,
    createdAt: bronzeAt,
    updatedAt: silverAt,
  );
}

class _MemoryRewardLedgerRepository implements RewardLedgerRepository {
  _MemoryRewardLedgerRepository({
    List<ChallengeMedalReward> rewards = const <ChallengeMedalReward>[],
  }) : _rewards = List<ChallengeMedalReward>.from(rewards);

  final List<ChallengeMedalReward> _rewards;

  @override
  Future<AchievementReward?> getAchievementReward({
    required String ownerId,
    required String rewardId,
  }) async {
    return null;
  }

  @override
  Future<RewardHistoryPage<AchievementReward>> listAchievementRewards({
    required String ownerId,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    return RewardHistoryPage<AchievementReward>(
      items: const <AchievementReward>[],
      nextCursor: null,
    );
  }

  @override
  Future<AchievementRewardWriteResult> unlockAchievement({
    required String ownerId,
    required AchievementAwardCandidate candidate,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChallengeMedalReward?> getChallengeMedal({
    required String ownerId,
    required String rewardId,
  }) async {
    for (final reward in _rewards) {
      if (reward.ownerId == ownerId && reward.id == rewardId) {
        return reward;
      }
    }
    return null;
  }

  @override
  Future<RewardHistoryPage<ChallengeMedalReward>> listChallengeMedals({
    required String ownerId,
    ChallengePeriod? period,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    final items = _rewards
        .where(
          (reward) =>
              reward.ownerId == ownerId &&
              (period == null || reward.period == period),
        )
        .take(limit)
        .toList(growable: false);
    return RewardHistoryPage<ChallengeMedalReward>(
      items: items,
      nextCursor: null,
    );
  }

  @override
  Future<RewardLedgerWriteResult> upsertChallengeMedal({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }
}

class _MemoryChallengeProgressRepository
    implements ChallengeProgressRepository {
  _MemoryChallengeProgressRepository({List<ActivityDaySummary> days = const []})
    : _days = List<ActivityDaySummary>.from(days);

  final List<ActivityDaySummary> _days;
  String? lastStart;
  String? lastEnd;

  @override
  Future<List<ActivityDaySummary>> listActivityDays({
    required String ownerId,
    required String startLocalDateInclusive,
    required String endLocalDateExclusive,
  }) async {
    lastStart = startLocalDateInclusive;
    lastEnd = endLocalDateExclusive;
    return _days
        .where(
          (day) =>
              day.ownerId == ownerId &&
              day.localDate.compareTo(startLocalDateInclusive) >= 0 &&
              day.localDate.compareTo(endLocalDateExclusive) < 0,
        )
        .toList(growable: false);
  }

  @override
  Future<List<ChallengeContributionRecord>> listContributions({
    required String ownerId,
  }) async {
    return const <ChallengeContributionRecord>[];
  }

  @override
  Future<ActivityDaySummary?> getActivityDay({
    required String ownerId,
    required String localDate,
  }) async {
    for (final day in _days) {
      if (day.ownerId == ownerId && day.localDate == localDate) {
        return day;
      }
    }
    return null;
  }

  @override
  Future<ChallengeContributionRecord?> getContribution({
    required String ownerId,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Future<bool> removeContribution({
    required String ownerId,
    required String sessionId,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChallengeContributionWriteResult> upsertContribution({
    required String ownerId,
    required ChallengeContribution contribution,
    required DateTime now,
  }) async {
    throw UnimplementedError();
  }
}
