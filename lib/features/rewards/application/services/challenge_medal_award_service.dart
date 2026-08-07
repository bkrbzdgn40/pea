import '../../../challenges/application/repositories/challenge_progress_repository.dart';
import '../../../challenges/domain/challenge_catalog.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/challenge_period_window.dart';
import '../../../challenges/domain/models/medal_tier.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';
import '../../domain/challenge_period_progress_calculator.dart';
import '../../domain/models/challenge_medal_award_candidate.dart';
import '../../domain/models/challenge_medal_migration_policy.dart';
import '../../domain/models/challenge_medal_reward.dart';
import '../../domain/models/reward_evaluation_origin.dart';
import '../../domain/models/reward_ledger_mutation.dart';
import '../repositories/reward_ledger_repository.dart';

class ChallengeMedalAwardService {
  factory ChallengeMedalAwardService({
    required ChallengeProgressRepository progressRepository,
    required RewardLedgerRepository rewardRepository,
    required ChallengeMedalMigrationPolicy migrationPolicy,
    ChallengeCatalog catalog = const ChallengeCatalog(),
    ChallengePeriodProgressCalculator progressCalculator =
        const ChallengePeriodProgressCalculator(),
  }) {
    return ChallengeMedalAwardService._(
      progressRepository,
      rewardRepository,
      migrationPolicy,
      catalog,
      progressCalculator,
    );
  }

  const ChallengeMedalAwardService._(
    this._progressRepository,
    this._rewardRepository,
    this._migrationPolicy,
    this._catalog,
    this._progressCalculator,
  );

  final ChallengeProgressRepository _progressRepository;
  final RewardLedgerRepository _rewardRepository;
  final ChallengeMedalMigrationPolicy _migrationPolicy;
  final ChallengeCatalog _catalog;
  final ChallengePeriodProgressCalculator _progressCalculator;

  Future<ChallengeMedalAwardOutcome> evaluatePeriod({
    required String ownerId,
    required ExerciseType exerciseType,
    required ChallengePeriod period,
    required DateTime qualifyingEventAt,
    required Duration timezoneOffset,
    required String qualifyingEventId,
    required RewardEvaluationOrigin origin,
    required DateTime now,
  }) async {
    final definition = _catalog.definitionFor(exerciseType);
    final window = ChallengePeriodWindow.forInstant(
      period: period,
      instant: qualifyingEventAt,
      timezoneOffset: timezoneOffset,
    );
    if (!_migrationPolicy.allows(window: window, origin: origin)) {
      return ChallengeMedalAwardOutcome.blockedByMigrationPolicy(
        period: period,
        periodKey: window.key,
      );
    }

    final days = await _progressRepository.listActivityDays(
      ownerId: ownerId,
      startLocalDateInclusive: window.startLocalDateKey,
      endLocalDateExclusive: window.endLocalDateExclusiveKey,
    );
    final progressValue = _progressCalculator.calculate(
      definition: definition,
      window: window,
      activityDays: days,
    );
    final tier = definition.thresholdsFor(period).tierFor(progressValue);
    if (tier == MedalTier.none) {
      return ChallengeMedalAwardOutcome.belowBronze(
        period: period,
        periodKey: window.key,
        progressValue: progressValue,
      );
    }

    final result = await _rewardRepository.upsertChallengeMedal(
      ownerId: ownerId,
      candidate: ChallengeMedalAwardCandidate(
        definition: definition,
        window: window,
        tier: tier,
        progressValue: progressValue,
        qualifyingEventId: qualifyingEventId,
        qualifiedAt: qualifyingEventAt,
      ),
      now: now,
    );
    return ChallengeMedalAwardOutcome.persisted(
      period: period,
      periodKey: window.key,
      progressValue: progressValue,
      writeResult: result,
    );
  }
}

enum ChallengeMedalAwardStatus {
  blockedByMigrationPolicy,
  belowBronze,
  created,
  upgraded,
  unchanged,
}

class ChallengeMedalAwardOutcome {
  const ChallengeMedalAwardOutcome._({
    required this.status,
    required this.period,
    required this.periodKey,
    required this.progressValue,
    required this.reward,
  });

  factory ChallengeMedalAwardOutcome.blockedByMigrationPolicy({
    required ChallengePeriod period,
    required String periodKey,
  }) {
    return ChallengeMedalAwardOutcome._(
      status: ChallengeMedalAwardStatus.blockedByMigrationPolicy,
      period: period,
      periodKey: periodKey,
      progressValue: 0,
      reward: null,
    );
  }

  factory ChallengeMedalAwardOutcome.belowBronze({
    required ChallengePeriod period,
    required String periodKey,
    required double progressValue,
  }) {
    return ChallengeMedalAwardOutcome._(
      status: ChallengeMedalAwardStatus.belowBronze,
      period: period,
      periodKey: periodKey,
      progressValue: progressValue,
      reward: null,
    );
  }

  factory ChallengeMedalAwardOutcome.persisted({
    required ChallengePeriod period,
    required String periodKey,
    required double progressValue,
    required RewardLedgerWriteResult writeResult,
  }) {
    return ChallengeMedalAwardOutcome._(
      status: switch (writeResult.status) {
        RewardLedgerWriteStatus.created => ChallengeMedalAwardStatus.created,
        RewardLedgerWriteStatus.upgraded => ChallengeMedalAwardStatus.upgraded,
        RewardLedgerWriteStatus.unchanged =>
          ChallengeMedalAwardStatus.unchanged,
      },
      period: period,
      periodKey: periodKey,
      progressValue: progressValue,
      reward: writeResult.reward,
    );
  }

  final ChallengeMedalAwardStatus status;
  final ChallengePeriod period;
  final String periodKey;
  final double progressValue;
  final ChallengeMedalReward? reward;
}
