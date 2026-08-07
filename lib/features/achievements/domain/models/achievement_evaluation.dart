import 'achievement_definition.dart';

class AchievementEvaluation {
  const AchievementEvaluation({
    required this.definition,
    required this.isUnlocked,
    required this.current,
    required this.target,
    this.qualifyingEventId,
  });

  final AchievementDefinition definition;
  final bool isUnlocked;
  final int current;
  final int target;
  final String? qualifyingEventId;

  double get normalizedProgress {
    if (target <= 0) {
      return isUnlocked ? 1 : 0;
    }
    return (current / target).clamp(0, 1).toDouble();
  }

  int get remaining =>
      isUnlocked ? 0 : (target - current).clamp(0, target).toInt();
}
