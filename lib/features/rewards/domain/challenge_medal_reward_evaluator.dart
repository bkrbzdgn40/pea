import '../../challenges/domain/models/medal_tier.dart';
import 'models/challenge_medal_award_candidate.dart';
import 'models/challenge_medal_reward.dart';
import 'models/reward_ledger_mutation.dart';

/// Creates or upgrades one deterministic period reward without ever downgrading it.
class ChallengeMedalRewardEvaluator {
  const ChallengeMedalRewardEvaluator();

  RewardLedgerWriteResult evaluate({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required ChallengeMedalReward? existing,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    if (nowUtc.isBefore(candidate.qualifiedAtUtc)) {
      throw StateError(
        'Reward write time cannot precede its qualifying event.',
      );
    }
    if (existing == null) {
      final earnedAt = <MedalTier, DateTime>{};
      for (final tier in _earnedTiersThrough(candidate.tier)) {
        earnedAt[tier] = candidate.qualifiedAtUtc;
      }
      return RewardLedgerWriteResult(
        status: RewardLedgerWriteStatus.created,
        reward: ChallengeMedalReward(
          ownerId: ownerId,
          challengeId: candidate.definition.id,
          catalogVersion: candidate.definition.catalogVersion,
          exerciseType: candidate.definition.exerciseType,
          metric: candidate.definition.metric,
          period: candidate.window.period,
          periodKey: candidate.window.key,
          timezoneOffset: candidate.window.timezoneOffset,
          highestTier: candidate.tier,
          progressValueAtHighestTier: candidate.progressValue,
          thresholdsAtAward: candidate.definition.thresholdsFor(
            candidate.window.period,
          ),
          tierEarnedAt: earnedAt,
          qualifyingEventId: candidate.qualifyingEventId,
          isBackfilled: false,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );
    }

    if (existing.ownerId != ownerId || !existing.hasSameIdentityAs(candidate)) {
      throw StateError(
        'Existing reward metadata does not match the award candidate.',
      );
    }
    if (candidate.tier.rank <= existing.highestTier.rank) {
      return RewardLedgerWriteResult(
        status: RewardLedgerWriteStatus.unchanged,
        reward: existing,
      );
    }

    if (!nowUtc.isAfter(existing.updatedAtUtc)) {
      throw StateError('Reward upgrades require a later update timestamp.');
    }
    if (candidate.qualifiedAtUtc.isBefore(existing.highestTierEarnedAtUtc)) {
      throw StateError('A higher tier cannot predate the current medal tier.');
    }

    final earnedAt = Map<MedalTier, DateTime>.from(existing.tierEarnedAtUtc);
    for (final tier in _earnedTiersThrough(candidate.tier)) {
      earnedAt.putIfAbsent(tier, () => candidate.qualifiedAtUtc);
    }

    return RewardLedgerWriteResult(
      status: RewardLedgerWriteStatus.upgraded,
      reward: ChallengeMedalReward(
        ownerId: existing.ownerId,
        challengeId: existing.challengeId,
        catalogVersion: existing.catalogVersion,
        exerciseType: existing.exerciseType,
        metric: existing.metric,
        period: existing.period,
        periodKey: existing.periodKey,
        timezoneOffset: existing.timezoneOffset,
        highestTier: candidate.tier,
        progressValueAtHighestTier: candidate.progressValue,
        thresholdsAtAward: existing.thresholdsAtAward,
        tierEarnedAt: earnedAt,
        qualifyingEventId: candidate.qualifyingEventId,
        isBackfilled: existing.isBackfilled,
        createdAt: existing.createdAtUtc,
        updatedAt: nowUtc,
      ),
    );
  }
}

Iterable<MedalTier> _earnedTiersThrough(MedalTier highestTier) sync* {
  for (final tier in const <MedalTier>[
    MedalTier.bronze,
    MedalTier.silver,
    MedalTier.gold,
  ]) {
    if (tier.rank > highestTier.rank) {
      return;
    }
    yield tier;
  }
}
