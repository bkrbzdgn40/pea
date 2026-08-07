import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/repositories/achievement_event_repository.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event_record.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievement_event_providers.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/challenges/application/repositories/challenge_progress_repository.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/activity_day_summary.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution_record.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_progress_mutation.dart';
import 'package:pose_estimation_app/features/challenges/presentation/providers/challenge_progress_providers.dart';
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
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'real snapshot exposes visible catalog without score achievements',
    () async {
      final container = _container(
        snapshot: UserSessionsSnapshot(
          sessions: [
            buildWorkoutSession(
              id: 'reliable-squat',
              startedAt: DateTime(2026, 8, 1),
              totalReps: 8,
              preparationOutcome: PreparationOutcome.passed,
              measurementQuality: SessionMeasurementQuality.high,
              averageMeasurementConfidence: 0.95,
              measurementSampleCount: 8,
            ),
          ],
          source: UserSessionsSnapshotSource.real,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);

      expect(state.source, AchievementsDataSource.real);
      expect(state.achievements, hasLength(8));
      expect(
        state.achievements.any((item) => item.id == 'score_90_plus'),
        isFalse,
      );
      expect(
        state.achievements.any((item) => item.id == 'hundred_reps'),
        isFalse,
      );
      expect(
        _achievementById(
          state.achievements,
          'first_reliable_analysis',
        ).isUnlocked,
        isTrue,
      );
    },
  );

  test(
    'limited and legacy evidence cannot unlock reliable achievements',
    () async {
      final container = _container(
        snapshot: UserSessionsSnapshot(
          sessions: [
            buildWorkoutSession(
              id: 'limited',
              startedAt: DateTime(2026, 8, 1),
              totalReps: 100,
              averageScore: 100,
              preparationOutcome: PreparationOutcome.passed,
              measurementQuality: SessionMeasurementQuality.limited,
              averageMeasurementConfidence: 0.7,
              measurementSampleCount: 100,
            ),
            buildWorkoutSession(
              id: 'legacy',
              startedAt: DateTime(2026, 8, 2),
              totalReps: 100,
            ),
          ],
          source: UserSessionsSnapshotSource.real,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);

      expect(
        _achievementById(
          state.achievements,
          'first_reliable_analysis',
        ).isUnlocked,
        isFalse,
      );
      expect(
        _achievementById(state.achievements, 'reliable_sessions_5').progress,
        0,
      );
    },
  );

  test('guide events feed the single meaningful next achievement', () async {
    final firstReward = _achievementReward(
      id: 'first_reliable_analysis',
      unlockedAt: DateTime.utc(2026, 8, 1, 10),
    );
    final events = <AchievementEventRecord>[
      for (var step = 1; step <= 5; step++)
        _guideEvent(step.toString(), DateTime.utc(2026, 8, 2, 10, step)),
    ];
    final container = _container(
      ownerId: 'owner-1',
      snapshot: const UserSessionsSnapshot(
        sessions: [],
        source: UserSessionsSnapshotSource.empty,
      ),
      events: events,
      achievementRewards: [firstReward],
    );
    addTearDown(container.dispose);

    final state = await container.read(achievementsProvider.future);

    expect(state.nextAchievement?.id, 'guide_completed');
    expect(state.nextAchievement?.current, 5);
    expect(state.nextAchievement?.target, 6);
  });

  test(
    'earned hidden achievements appear while locked secrets stay hidden',
    () async {
      final hidden = _achievementReward(
        id: 'return_after_14_days',
        unlockedAt: DateTime.utc(2026, 8, 4, 12),
      );
      final container = _container(
        ownerId: 'owner-1',
        snapshot: const UserSessionsSnapshot(
          sessions: [],
          source: UserSessionsSnapshotSource.empty,
        ),
        achievementRewards: [hidden],
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);

      expect(
        _achievementById(state.achievements, 'return_after_14_days').isSecret,
        isTrue,
      );
      expect(
        state.achievements.any((item) => item.id == 'golden_week'),
        isFalse,
      );
    },
  );

  test(
    'empty signed-in state still presents a useful first next step',
    () async {
      final container = _container(
        ownerId: 'owner-1',
        snapshot: const UserSessionsSnapshot(
          sessions: [],
          source: UserSessionsSnapshotSource.empty,
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(achievementsProvider.future);

      expect(state.source, AchievementsDataSource.empty);
      expect(state.achievements, hasLength(8));
      expect(state.earnedAchievements, isEmpty);
      expect(state.nextAchievement?.id, 'first_reliable_analysis');
    },
  );
}

ProviderContainer _container({
  required UserSessionsSnapshot snapshot,
  String? ownerId,
  List<ChallengeContributionRecord> contributions = const [],
  List<AchievementEventRecord> events = const [],
  List<AchievementReward> achievementRewards = const [],
  List<ChallengeMedalReward> medalRewards = const [],
}) {
  return ProviderContainer(
    overrides: [
      userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
      achievementsOwnerIdProvider.overrideWithValue(ownerId),
      challengeProgressRepositoryProvider.overrideWithValue(
        _MemoryChallengeProgressRepository(contributions),
      ),
      achievementEventRepositoryProvider.overrideWithValue(
        _MemoryAchievementEventRepository(events),
      ),
      rewardLedgerRepositoryProvider.overrideWithValue(
        _MemoryRewardLedgerRepository(
          achievementRewards: achievementRewards,
          medalRewards: medalRewards,
        ),
      ),
    ],
  );
}

Achievement _achievementById(List<Achievement> achievements, String id) {
  return achievements.singleWhere((achievement) => achievement.id == id);
}

AchievementReward _achievementReward({
  required String id,
  required DateTime unlockedAt,
}) {
  return AchievementReward(
    ownerId: 'owner-1',
    achievementId: id,
    definitionVersion: 1,
    unlockedAt: unlockedAt,
    qualifyingEventId: 'event-$id',
    isBackfilled: false,
    createdAt: unlockedAt,
    updatedAt: unlockedAt,
  );
}

AchievementEventRecord _guideEvent(String stepId, DateTime at) {
  return AchievementEventRecord(
    ownerId: 'owner-1',
    event: AchievementEvent.guideStepOpened(stepId: stepId, occurredAt: at),
    localDate:
        '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}',
    timezoneOffset: Duration.zero,
    createdAt: at,
  );
}

class _MemoryChallengeProgressRepository
    implements ChallengeProgressRepository {
  _MemoryChallengeProgressRepository(this.contributions);

  final List<ChallengeContributionRecord> contributions;

  @override
  Future<List<ChallengeContributionRecord>> listContributions({
    required String ownerId,
  }) async => List.unmodifiable(contributions);

  @override
  Future<ActivityDaySummary?> getActivityDay({
    required String ownerId,
    required String localDate,
  }) async => null;

  @override
  Future<ChallengeContributionRecord?> getContribution({
    required String ownerId,
    required String sessionId,
  }) async => null;

  @override
  Future<List<ActivityDaySummary>> listActivityDays({
    required String ownerId,
    required String startLocalDateInclusive,
    required String endLocalDateExclusive,
  }) async => const [];

  @override
  Future<bool> removeContribution({
    required String ownerId,
    required String sessionId,
    required DateTime now,
  }) async => false;

  @override
  Future<ChallengeContributionWriteResult> upsertContribution({
    required String ownerId,
    required ChallengeContribution contribution,
    required DateTime now,
  }) async => throw UnimplementedError();
}

class _MemoryAchievementEventRepository implements AchievementEventRepository {
  _MemoryAchievementEventRepository(this.events);

  final List<AchievementEventRecord> events;

  @override
  Future<List<AchievementEventRecord>> listEvents({
    required String ownerId,
  }) async => List.unmodifiable(events);

  @override
  Future<AchievementEventWriteResult> recordEvent({
    required String ownerId,
    required AchievementEvent event,
    required Duration timezoneOffset,
    required DateTime now,
  }) async => throw UnimplementedError();
}

class _MemoryRewardLedgerRepository implements RewardLedgerRepository {
  _MemoryRewardLedgerRepository({
    required this.achievementRewards,
    required this.medalRewards,
  });

  final List<AchievementReward> achievementRewards;
  final List<ChallengeMedalReward> medalRewards;

  @override
  Future<RewardHistoryPage<AchievementReward>> listAchievementRewards({
    required String ownerId,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    return RewardHistoryPage(items: achievementRewards, nextCursor: null);
  }

  @override
  Future<RewardHistoryPage<ChallengeMedalReward>> listChallengeMedals({
    required String ownerId,
    ChallengePeriod? period,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    return RewardHistoryPage(
      items: medalRewards
          .where((reward) => period == null || reward.period == period)
          .toList(),
      nextCursor: null,
    );
  }

  @override
  Future<AchievementReward?> getAchievementReward({
    required String ownerId,
    required String rewardId,
  }) async => null;

  @override
  Future<ChallengeMedalReward?> getChallengeMedal({
    required String ownerId,
    required String rewardId,
  }) async => null;

  @override
  Future<AchievementRewardWriteResult> unlockAchievement({
    required String ownerId,
    required AchievementAwardCandidate candidate,
    required DateTime now,
  }) async => throw UnimplementedError();

  @override
  Future<RewardLedgerWriteResult> upsertChallengeMedal({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required DateTime now,
  }) async => throw UnimplementedError();
}
