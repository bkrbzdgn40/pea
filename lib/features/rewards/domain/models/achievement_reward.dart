import '../../../achievements/domain/achievement_catalog.dart';
import '../../../achievements/domain/models/achievement_definition.dart';
import 'reward_kind.dart';
import 'user_reward.dart';

class AchievementReward implements UserReward {
  AchievementReward({
    required this.ownerId,
    required this.achievementId,
    required this.definitionVersion,
    required DateTime unlockedAt,
    required this.qualifyingEventId,
    required this.isBackfilled,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : unlockedAtUtc = unlockedAt.toUtc(),
       createdAtUtc = createdAt.toUtc(),
       updatedAtUtc = updatedAt.toUtc() {
    _validate();
  }

  @override
  final String ownerId;
  final String achievementId;
  final int definitionVersion;
  final DateTime unlockedAtUtc;
  final String qualifyingEventId;
  final bool isBackfilled;
  @override
  final DateTime createdAtUtc;
  @override
  final DateTime updatedAtUtc;

  @override
  RewardKind get kind => RewardKind.achievement;

  @override
  String get id => achievementRewardId(achievementId);

  @override
  DateTime get historyAtUtc => unlockedAtUtc;

  void _validate() {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Invalid document id.');
    }
    if (achievementId.isEmpty || achievementId.contains('/')) {
      throw ArgumentError.value(
        achievementId,
        'achievementId',
        'Invalid achievement id.',
      );
    }
    if (definitionVersion <= 0) {
      throw ArgumentError.value(
        definitionVersion,
        'definitionVersion',
        'Must be positive.',
      );
    }
    final definition = const AchievementCatalog().byId(achievementId);
    if (definitionVersion != definition.definitionVersion) {
      throw ArgumentError(
        'Achievement definition version does not match catalog.',
      );
    }
    if (isBackfilled && !definition.allowsHistoricalBackfill) {
      throw ArgumentError(
        'Historical backfill is disabled for $achievementId.',
      );
    }
    if (qualifyingEventId.isEmpty || qualifyingEventId.contains('/')) {
      throw ArgumentError.value(
        qualifyingEventId,
        'qualifyingEventId',
        'Must be non-empty and must not contain a slash.',
      );
    }
    if (createdAtUtc.isBefore(unlockedAtUtc)) {
      throw ArgumentError('createdAt must not precede unlockedAt.');
    }
    if (updatedAtUtc.isBefore(createdAtUtc)) {
      throw ArgumentError('updatedAt must not precede createdAt.');
    }
  }
}

String achievementRewardId(String achievementId) {
  if (achievementId.isEmpty || achievementId.contains('/')) {
    throw ArgumentError.value(
      achievementId,
      'achievementId',
      'Invalid achievement id.',
    );
  }
  return 'achievement:$achievementId';
}

bool achievementAllowsHistoricalBackfill(AchievementDefinition definition) {
  return definition.allowsHistoricalBackfill;
}
