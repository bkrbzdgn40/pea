import 'achievement_visibility.dart';

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.definitionVersion,
    required this.visibility,
    required this.allowsHistoricalBackfill,
  });

  final String id;
  final int definitionVersion;
  final AchievementVisibility visibility;
  final bool allowsHistoricalBackfill;

  String get rewardId => 'achievement:$id';
}
