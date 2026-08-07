import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_paths.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../application/repositories/reward_ledger_repository.dart';
import '../../domain/challenge_medal_reward_evaluator.dart';
import '../../domain/models/achievement_award_candidate.dart';
import '../../domain/models/achievement_reward.dart';
import '../../domain/models/achievement_reward_mutation.dart';
import '../../domain/models/challenge_medal_award_candidate.dart';
import '../../domain/models/challenge_medal_reward.dart';
import '../../domain/models/reward_history_cursor.dart';
import '../../domain/models/reward_history_page.dart';
import '../../domain/models/reward_kind.dart';
import '../../domain/models/reward_ledger_mutation.dart';
import '../mappers/achievement_reward_firestore_mapper.dart';
import '../mappers/challenge_medal_reward_firestore_mapper.dart';

class FirestoreRewardLedgerRepository implements RewardLedgerRepository {
  factory FirestoreRewardLedgerRepository(
    FirebaseFirestore firestore, {
    ChallengeMedalRewardFirestoreMapper mapper =
        const ChallengeMedalRewardFirestoreMapper(),
    ChallengeMedalRewardEvaluator evaluator =
        const ChallengeMedalRewardEvaluator(),
    AchievementRewardFirestoreMapper achievementMapper =
        const AchievementRewardFirestoreMapper(),
  }) {
    return FirestoreRewardLedgerRepository._(
      firestore,
      mapper,
      evaluator,
      achievementMapper,
    );
  }

  FirestoreRewardLedgerRepository._(
    this._firestore,
    this._mapper,
    this._evaluator,
    this._achievementMapper,
  );

  final FirebaseFirestore _firestore;
  final ChallengeMedalRewardFirestoreMapper _mapper;
  final ChallengeMedalRewardEvaluator _evaluator;
  final AchievementRewardFirestoreMapper _achievementMapper;

  @override
  Future<AchievementRewardWriteResult> unlockAchievement({
    required String ownerId,
    required AchievementAwardCandidate candidate,
    required DateTime now,
  }) {
    _validateDocumentId(ownerId, 'ownerId');
    final reference = _rewardDocument(ownerId, candidate.rewardId);
    final nowUtc = now.toUtc();
    if (nowUtc.isBefore(candidate.unlockedAtUtc)) {
      throw ArgumentError('now must not precede unlockedAt.');
    }

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        final existing = _decodeAchievement(snapshot, expectedOwnerId: ownerId);
        return AchievementRewardWriteResult(
          status: RewardLedgerWriteStatus.unchanged,
          reward: existing,
        );
      }

      final reward = AchievementReward(
        ownerId: ownerId,
        achievementId: candidate.definition.id,
        definitionVersion: candidate.definition.definitionVersion,
        unlockedAt: candidate.unlockedAtUtc,
        qualifyingEventId: candidate.qualifyingEventId,
        isBackfilled: candidate.isBackfilled,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );
      transaction.set(reference, _achievementMapper.toDocument(reward));
      return AchievementRewardWriteResult(
        status: RewardLedgerWriteStatus.created,
        reward: reward,
      );
    });
  }

  @override
  Future<AchievementReward?> getAchievementReward({
    required String ownerId,
    required String rewardId,
  }) async {
    _validateDocumentId(ownerId, 'ownerId');
    _validateDocumentId(rewardId, 'rewardId');
    final snapshot = await _rewardDocument(ownerId, rewardId).get();
    if (!snapshot.exists) {
      return null;
    }
    return _decodeAchievement(snapshot, expectedOwnerId: ownerId);
  }

  @override
  Future<RewardHistoryPage<AchievementReward>> listAchievementRewards({
    required String ownerId,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    _validateDocumentId(ownerId, 'ownerId');
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }

    Query<Map<String, dynamic>> query = _rewardsCollection(ownerId)
        .where('kind', isEqualTo: RewardKind.achievement.storageValue)
        .orderBy('historyAt', descending: true)
        .orderBy('id', descending: true);
    if (startAfter != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(startAfter.sortAtUtc),
        startAfter.rewardId,
      ]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final visibleDocs = hasMore
        ? snapshot.docs.take(limit).toList(growable: false)
        : snapshot.docs;
    final items = visibleDocs
        .map(
          (document) => _decodeAchievement(document, expectedOwnerId: ownerId),
        )
        .toList(growable: false);
    final last = items.isEmpty ? null : items.last;
    return RewardHistoryPage<AchievementReward>(
      items: items,
      nextCursor: hasMore && last != null
          ? RewardHistoryCursor(sortAt: last.historyAtUtc, rewardId: last.id)
          : null,
    );
  }

  @override
  Future<RewardLedgerWriteResult> upsertChallengeMedal({
    required String ownerId,
    required ChallengeMedalAwardCandidate candidate,
    required DateTime now,
  }) {
    _validateDocumentId(ownerId, 'ownerId');
    final reference = _rewardDocument(ownerId, candidate.rewardId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final existing = snapshot.exists
          ? _decode(snapshot, expectedOwnerId: ownerId)
          : null;
      final result = _evaluator.evaluate(
        ownerId: ownerId,
        candidate: candidate,
        existing: existing,
        now: now,
      );
      if (result.status != RewardLedgerWriteStatus.unchanged) {
        transaction.set(reference, _mapper.toDocument(result.reward));
      }
      return result;
    });
  }

  @override
  Future<ChallengeMedalReward?> getChallengeMedal({
    required String ownerId,
    required String rewardId,
  }) async {
    _validateDocumentId(ownerId, 'ownerId');
    _validateDocumentId(rewardId, 'rewardId');
    final snapshot = await _rewardDocument(ownerId, rewardId).get();
    if (!snapshot.exists) {
      return null;
    }
    return _decode(snapshot, expectedOwnerId: ownerId);
  }

  @override
  Future<RewardHistoryPage<ChallengeMedalReward>> listChallengeMedals({
    required String ownerId,
    ChallengePeriod? period,
    int limit = 20,
    RewardHistoryCursor? startAfter,
  }) async {
    _validateDocumentId(ownerId, 'ownerId');
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 50.');
    }

    Query<Map<String, dynamic>> query = _rewardsCollection(
      ownerId,
    ).where('kind', isEqualTo: RewardKind.challengeMedal.storageValue);
    if (period != null) {
      query = query.where('period', isEqualTo: period.storageValue);
    }
    query = query
        .orderBy('historyAt', descending: true)
        .orderBy('id', descending: true);
    if (startAfter != null) {
      query = query.startAfter(<Object>[
        Timestamp.fromDate(startAfter.sortAtUtc),
        startAfter.rewardId,
      ]);
    }

    final snapshot = await query.limit(limit + 1).get();
    final hasMore = snapshot.docs.length > limit;
    final visibleDocs = hasMore
        ? snapshot.docs.take(limit).toList(growable: false)
        : snapshot.docs;
    final items = visibleDocs
        .map((document) => _decode(document, expectedOwnerId: ownerId))
        .toList(growable: false);
    final last = items.isEmpty ? null : items.last;

    return RewardHistoryPage<ChallengeMedalReward>(
      items: items,
      nextCursor: hasMore && last != null
          ? RewardHistoryCursor(sortAt: last.historyAtUtc, rewardId: last.id)
          : null,
    );
  }

  AchievementReward _decodeAchievement(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String expectedOwnerId,
  }) {
    final reward = _achievementMapper.fromDocument(
      documentId: snapshot.id,
      data: snapshot.data()!,
    );
    if (reward.ownerId != expectedOwnerId) {
      throw const FormatException('Reward owner does not match its path.');
    }
    return reward;
  }

  ChallengeMedalReward _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String expectedOwnerId,
  }) {
    final reward = _mapper.fromDocument(
      documentId: snapshot.id,
      data: snapshot.data()!,
    );
    if (reward.ownerId != expectedOwnerId) {
      throw const FormatException('Reward owner does not match its path.');
    }
    return reward;
  }

  CollectionReference<Map<String, dynamic>> _rewardsCollection(String ownerId) {
    return _firestore.collection(FirestorePaths.userRewards(ownerId));
  }

  DocumentReference<Map<String, dynamic>> _rewardDocument(
    String ownerId,
    String rewardId,
  ) {
    return _firestore.doc(FirestorePaths.userRewardDoc(ownerId, rewardId));
  }
}

void _validateDocumentId(String value, String name) {
  if (value.isEmpty || value.contains('/')) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a non-empty Firestore document id.',
    );
  }
}
