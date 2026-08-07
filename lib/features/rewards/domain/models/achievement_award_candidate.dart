import '../../../achievements/domain/achievement_catalog.dart';
import '../../../achievements/domain/models/achievement_definition.dart';
import 'achievement_reward.dart';

class AchievementAwardCandidate {
  AchievementAwardCandidate({
    required this.definition,
    required DateTime unlockedAt,
    required this.qualifyingEventId,
    this.isBackfilled = false,
  }) : unlockedAtUtc = unlockedAt.toUtc() {
    final canonical = const AchievementCatalog().byId(definition.id);
    if (canonical.definitionVersion != definition.definitionVersion ||
        canonical.visibility != definition.visibility ||
        canonical.allowsHistoricalBackfill !=
            definition.allowsHistoricalBackfill) {
      throw ArgumentError('Achievement definition does not match catalog.');
    }
    if (qualifyingEventId.isEmpty || qualifyingEventId.contains('/')) {
      throw ArgumentError.value(
        qualifyingEventId,
        'qualifyingEventId',
        'Must be non-empty and must not contain a slash.',
      );
    }
    if (isBackfilled && !definition.allowsHistoricalBackfill) {
      throw ArgumentError(
        'Historical backfill is disabled for ${definition.id}.',
      );
    }
  }

  final AchievementDefinition definition;
  final DateTime unlockedAtUtc;
  final String qualifyingEventId;
  final bool isBackfilled;

  String get rewardId => achievementRewardId(definition.id);
}
