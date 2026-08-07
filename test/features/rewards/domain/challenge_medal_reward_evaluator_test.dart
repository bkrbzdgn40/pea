import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_definition.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/rewards/domain/challenge_medal_reward_evaluator.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_award_candidate.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/reward_ledger_mutation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const evaluator = ChallengeMedalRewardEvaluator();
  final definition = const ChallengeCatalog().definitionFor(
    ExerciseType.pushUp,
  );

  test('creates one reward and records every crossed tier', () {
    final qualifiedAt = DateTime.utc(2026, 8, 7, 8);
    final result = evaluator.evaluate(
      ownerId: 'user-1',
      candidate: _candidate(
        definition: definition,
        tier: MedalTier.gold,
        progress: 30,
        qualifiedAt: qualifiedAt,
      ),
      existing: null,
      now: qualifiedAt.add(const Duration(seconds: 2)),
    );

    expect(result.status, RewardLedgerWriteStatus.created);
    expect(result.reward.highestTier, MedalTier.gold);
    expect(result.reward.tierEarnedAtUtc, <MedalTier, DateTime>{
      MedalTier.bronze: qualifiedAt,
      MedalTier.silver: qualifiedAt,
      MedalTier.gold: qualifiedAt,
    });
    expect(result.reward.id, 'medal:push_up_volume:daily:2026-08-07');
  });

  test('upgrades the same reward while preserving prior timestamps', () {
    final bronzeAt = DateTime.utc(2026, 8, 7, 8);
    final created = evaluator.evaluate(
      ownerId: 'user-1',
      candidate: _candidate(
        definition: definition,
        tier: MedalTier.bronze,
        progress: 10,
        qualifiedAt: bronzeAt,
      ),
      existing: null,
      now: bronzeAt,
    );
    final silverAt = bronzeAt.add(const Duration(hours: 2));
    final upgraded = evaluator.evaluate(
      ownerId: 'user-1',
      candidate: _candidate(
        definition: definition,
        tier: MedalTier.silver,
        progress: 20,
        qualifiedAt: silverAt,
        eventId: 'session-2',
      ),
      existing: created.reward,
      now: silverAt.add(const Duration(seconds: 1)),
    );

    expect(upgraded.status, RewardLedgerWriteStatus.upgraded);
    expect(upgraded.reward.highestTier, MedalTier.silver);
    expect(upgraded.reward.tierEarnedAtUtc[MedalTier.bronze], bronzeAt);
    expect(upgraded.reward.tierEarnedAtUtc[MedalTier.silver], silverAt);
    expect(upgraded.reward.createdAtUtc, created.reward.createdAtUtc);
    expect(upgraded.reward.qualifyingEventId, 'session-2');
  });

  test('rejects a write timestamp before the qualifying event', () {
    final qualifiedAt = DateTime.utc(2026, 8, 7, 8);

    expect(
      () => evaluator.evaluate(
        ownerId: 'user-1',
        candidate: _candidate(
          definition: definition,
          tier: MedalTier.bronze,
          progress: 10,
          qualifiedAt: qualifiedAt,
        ),
        existing: null,
        now: qualifiedAt.subtract(const Duration(seconds: 1)),
      ),
      throwsStateError,
    );
  });

  test('same or lower tier is idempotent and never downgrades', () {
    final qualifiedAt = DateTime.utc(2026, 8, 7, 8);
    final created = evaluator.evaluate(
      ownerId: 'user-1',
      candidate: _candidate(
        definition: definition,
        tier: MedalTier.silver,
        progress: 20,
        qualifiedAt: qualifiedAt,
      ),
      existing: null,
      now: qualifiedAt,
    );
    final unchanged = evaluator.evaluate(
      ownerId: 'user-1',
      candidate: _candidate(
        definition: definition,
        tier: MedalTier.bronze,
        progress: 10,
        qualifiedAt: qualifiedAt,
        eventId: 'session-2',
      ),
      existing: created.reward,
      now: qualifiedAt.add(const Duration(hours: 1)),
    );

    expect(unchanged.status, RewardLedgerWriteStatus.unchanged);
    expect(identical(unchanged.reward, created.reward), isTrue);
    expect(unchanged.reward.highestTier, MedalTier.silver);
  });
}

ChallengeMedalAwardCandidate _candidate({
  required ChallengeDefinition definition,
  required MedalTier tier,
  required double progress,
  required DateTime qualifiedAt,
  String eventId = 'session-1',
}) {
  return ChallengeMedalAwardCandidate(
    definition: definition,
    window: ChallengePeriodWindow.forInstant(
      period: ChallengePeriod.daily,
      instant: qualifiedAt,
      timezoneOffset: Duration.zero,
    ),
    tier: tier,
    progressValue: progress,
    qualifyingEventId: eventId,
    qualifiedAt: qualifiedAt,
  );
}
