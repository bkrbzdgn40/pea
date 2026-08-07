import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/firebase/firestore_paths.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_ledger_mutation.dart';
import 'package:pose_estimation_app/features/rewards/infrastructure/repositories/firestore_reward_ledger_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('FirestoreRewardLedgerRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreRewardLedgerRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreRewardLedgerRepository(firestore);
    });

    test(
      'creates one immutable achievement reward and deduplicates it',
      () async {
        final unlockedAt = DateTime.utc(2026, 8, 7, 8);
        final candidate = AchievementAwardCandidate(
          definition: AchievementCatalog.firstReliableAnalysis,
          unlockedAt: unlockedAt,
          qualifyingEventId: 'session-1',
        );

        final created = await repository.unlockAchievement(
          ownerId: 'user-1',
          candidate: candidate,
          now: unlockedAt,
        );
        final duplicate = await repository.unlockAchievement(
          ownerId: 'user-1',
          candidate: AchievementAwardCandidate(
            definition: AchievementCatalog.firstReliableAnalysis,
            unlockedAt: unlockedAt.add(const Duration(hours: 1)),
            qualifyingEventId: 'session-2',
          ),
          now: unlockedAt.add(const Duration(hours: 1)),
        );

        expect(created.status, RewardLedgerWriteStatus.created);
        expect(duplicate.status, RewardLedgerWriteStatus.unchanged);
        expect(duplicate.reward.unlockedAtUtc, unlockedAt);
        expect(
          (await repository.listAchievementRewards(ownerId: 'user-1')).items,
          hasLength(1),
        );
      },
    );

    test('achievement history is newest first and paginates', () async {
      final firstAt = DateTime.utc(2026, 8, 7, 8);
      final secondAt = DateTime.utc(2026, 8, 8, 8);
      await repository.unlockAchievement(
        ownerId: 'user-1',
        candidate: AchievementAwardCandidate(
          definition: AchievementCatalog.firstReliableAnalysis,
          unlockedAt: firstAt,
          qualifyingEventId: 'session-1',
        ),
        now: firstAt,
      );
      await repository.unlockAchievement(
        ownerId: 'user-1',
        candidate: AchievementAwardCandidate(
          definition: AchievementCatalog.exerciseExplorer3,
          unlockedAt: secondAt,
          qualifyingEventId: 'session-2',
        ),
        now: secondAt,
      );

      final firstPage = await repository.listAchievementRewards(
        ownerId: 'user-1',
        limit: 1,
      );
      expect(firstPage.items.single.achievementId, 'exercise_explorer_3');
      expect(firstPage.nextCursor, isNotNull);

      final nextPage = await repository.listAchievementRewards(
        ownerId: 'user-1',
        limit: 1,
        startAfter: firstPage.nextCursor,
      );
      expect(nextPage.items.single.achievementId, 'first_reliable_analysis');
      expect(nextPage.nextCursor, isNull);
    });

    test(
      'creates, upgrades, and deduplicates one deterministic reward',
      () async {
        final bronzeAt = DateTime.utc(2026, 8, 7, 8);
        final bronze = _candidate(
          period: ChallengePeriod.daily,
          qualifiedAt: bronzeAt,
          tier: MedalTier.bronze,
          progress: 10,
        );
        final created = await repository.upsertChallengeMedal(
          ownerId: 'user-1',
          candidate: bronze,
          now: bronzeAt,
        );
        final duplicate = await repository.upsertChallengeMedal(
          ownerId: 'user-1',
          candidate: bronze,
          now: bronzeAt.add(const Duration(minutes: 1)),
        );
        final silverAt = bronzeAt.add(const Duration(hours: 2));
        final upgraded = await repository.upsertChallengeMedal(
          ownerId: 'user-1',
          candidate: _candidate(
            period: ChallengePeriod.daily,
            qualifiedAt: silverAt,
            tier: MedalTier.silver,
            progress: 20,
            eventId: 'session-2',
          ),
          now: silverAt,
        );

        expect(created.status, RewardLedgerWriteStatus.created);
        expect(duplicate.status, RewardLedgerWriteStatus.unchanged);
        expect(upgraded.status, RewardLedgerWriteStatus.upgraded);
        expect(upgraded.reward.highestTier, MedalTier.silver);
        expect(upgraded.reward.tierEarnedAtUtc[MedalTier.bronze], bronzeAt);
        expect(
          (await firestore
                  .collection(FirestorePaths.userRewards('user-1'))
                  .get())
              .docs,
          hasLength(1),
        );
      },
    );

    test('lists newest rewards first and filters by period', () async {
      await repository.upsertChallengeMedal(
        ownerId: 'user-1',
        candidate: _candidate(
          period: ChallengePeriod.weekly,
          qualifiedAt: DateTime.utc(2026, 8, 7, 8),
          tier: MedalTier.bronze,
          progress: 70,
        ),
        now: DateTime.utc(2026, 8, 7, 8),
      );
      await repository.upsertChallengeMedal(
        ownerId: 'user-1',
        candidate: _candidate(
          period: ChallengePeriod.daily,
          qualifiedAt: DateTime.utc(2026, 8, 8, 8),
          tier: MedalTier.bronze,
          progress: 10,
          eventId: 'session-2',
        ),
        now: DateTime.utc(2026, 8, 8, 8),
      );

      final all = await repository.listChallengeMedals(
        ownerId: 'user-1',
        limit: 1,
      );
      final weekly = await repository.listChallengeMedals(
        ownerId: 'user-1',
        period: ChallengePeriod.weekly,
      );

      expect(all.items, hasLength(1));
      expect(all.items.single.period, ChallengePeriod.daily);
      expect(all.nextCursor?.rewardId, all.items.single.id);

      final nextPage = await repository.listChallengeMedals(
        ownerId: 'user-1',
        limit: 1,
        startAfter: all.nextCursor,
      );
      expect(nextPage.items, hasLength(1));
      expect(nextPage.items.single.period, ChallengePeriod.weekly);
      expect(nextPage.nextCursor, isNull);

      expect(weekly.items, hasLength(1));
      expect(weekly.items.single.period, ChallengePeriod.weekly);
    });

    test('does not expose another owner reward through its path', () async {
      final candidate = _candidate(
        period: ChallengePeriod.daily,
        qualifiedAt: DateTime.utc(2026, 8, 7, 8),
        tier: MedalTier.bronze,
        progress: 10,
      );
      await repository.upsertChallengeMedal(
        ownerId: 'user-1',
        candidate: candidate,
        now: DateTime.utc(2026, 8, 7, 8),
      );

      expect(
        await repository.getChallengeMedal(
          ownerId: 'user-2',
          rewardId: candidate.rewardId,
        ),
        isNull,
      );
    });
  });
}

ChallengeMedalAwardCandidate _candidate({
  required ChallengePeriod period,
  required DateTime qualifiedAt,
  required MedalTier tier,
  required double progress,
  String eventId = 'session-1',
}) {
  final definition = const ChallengeCatalog().definitionFor(
    ExerciseType.pushUp,
  );
  return ChallengeMedalAwardCandidate(
    definition: definition,
    window: ChallengePeriodWindow.forInstant(
      period: period,
      instant: qualifiedAt,
      timezoneOffset: Duration.zero,
    ),
    tier: tier,
    progressValue: progress,
    qualifyingEventId: eventId,
    qualifiedAt: qualifiedAt,
  );
}
