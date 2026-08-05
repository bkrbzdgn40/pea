import '../../domain/models/user_workout_goal.dart';

class WorkoutGoal {
  const WorkoutGoal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.description,
    required this.isCompleted,
    this.type,
    this.status = WorkoutGoalStatus.active,
    this.progressAvailable = true,
  });

  final String id;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String description;
  final bool isCompleted;
  final WorkoutGoalType? type;
  final WorkoutGoalStatus status;
  final bool progressAvailable;

  bool get isActive => status == WorkoutGoalStatus.active;

  WorkoutGoalType? get resolvedType {
    final explicitType = type;
    if (explicitType != null) return explicitType;

    return switch (id) {
      'weekly_analysis_count' => WorkoutGoalType.weeklySessions,
      'total_reps_200' => WorkoutGoalType.weeklyReps,
      'average_score_85' => WorkoutGoalType.averageScore,
      _ => null,
    };
  }

  String get typeId => resolvedType?.storageValue ?? id;

  double get progress {
    if (!progressAvailable || targetValue <= 0) return 0;

    return (currentValue / targetValue).clamp(0, 1).toDouble();
  }
}
