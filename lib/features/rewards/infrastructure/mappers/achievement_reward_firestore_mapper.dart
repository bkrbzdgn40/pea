import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../achievements/domain/achievement_catalog.dart';
import '../../domain/models/achievement_reward.dart';
import '../../domain/models/reward_kind.dart';

class AchievementRewardFirestoreMapper {
  const AchievementRewardFirestoreMapper();

  static const int schemaVersion = 1;

  Map<String, Object?> toDocument(AchievementReward reward) {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'id': reward.id,
      'ownerId': reward.ownerId,
      'kind': reward.kind.storageValue,
      'achievementId': reward.achievementId,
      'definitionVersion': reward.definitionVersion,
      'unlockedAt': Timestamp.fromDate(reward.unlockedAtUtc),
      'historyAt': Timestamp.fromDate(reward.historyAtUtc),
      'qualifyingEventId': reward.qualifyingEventId,
      'isBackfilled': reward.isBackfilled,
      'createdAt': Timestamp.fromDate(reward.createdAtUtc),
      'updatedAt': Timestamp.fromDate(reward.updatedAtUtc),
    };
  }

  AchievementReward fromDocument({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final id = data['id'];
    final ownerId = data['ownerId'];
    final kind = data['kind'];
    final achievementId = data['achievementId'];
    final definitionVersion = data['definitionVersion'];
    final unlockedAt = data['unlockedAt'];
    final historyAt = data['historyAt'];
    final qualifyingEventId = data['qualifyingEventId'];
    final isBackfilled = data['isBackfilled'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    if (data['schemaVersion'] != schemaVersion ||
        id is! String ||
        id != documentId ||
        ownerId is! String ||
        kind != RewardKind.achievement.storageValue ||
        achievementId is! String ||
        definitionVersion is! int ||
        unlockedAt is! Timestamp ||
        historyAt is! Timestamp ||
        qualifyingEventId is! String ||
        isBackfilled is! bool ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw const FormatException('Invalid achievement reward document.');
    }

    final definition = const AchievementCatalog().byId(achievementId);
    if (definitionVersion != definition.definitionVersion ||
        (isBackfilled && !definition.allowsHistoricalBackfill) ||
        historyAt.toDate().toUtc() != unlockedAt.toDate().toUtc()) {
      throw const FormatException('Achievement reward contract mismatch.');
    }

    try {
      return AchievementReward(
        ownerId: ownerId,
        achievementId: achievementId,
        definitionVersion: definitionVersion,
        unlockedAt: unlockedAt.toDate(),
        qualifyingEventId: qualifyingEventId,
        isBackfilled: isBackfilled,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid achievement reward document: $error');
    }
  }
}
