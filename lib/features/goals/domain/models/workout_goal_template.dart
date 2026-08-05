import 'user_workout_goal.dart';

class WorkoutGoalTemplate {
  const WorkoutGoalTemplate({
    required this.type,
    required this.defaultTarget,
    required this.minimumTarget,
    required this.maximumTarget,
  });

  final WorkoutGoalType type;
  final double defaultTarget;
  final double minimumTarget;
  final double maximumTarget;

  bool get requiresWholeNumber => type != WorkoutGoalType.averageScore;

  bool accepts(double value) {
    return value.isFinite &&
        value >= minimumTarget &&
        value <= maximumTarget &&
        (!requiresWholeNumber || value == value.roundToDouble());
  }
}

const workoutGoalTemplates = <WorkoutGoalTemplate>[
  WorkoutGoalTemplate(
    type: WorkoutGoalType.weeklySessions,
    defaultTarget: 5,
    minimumTarget: 1,
    maximumTarget: 14,
  ),
  WorkoutGoalTemplate(
    type: WorkoutGoalType.weeklyReps,
    defaultTarget: 200,
    minimumTarget: 10,
    maximumTarget: 1000,
  ),
  WorkoutGoalTemplate(
    type: WorkoutGoalType.averageScore,
    defaultTarget: 85,
    minimumTarget: 1,
    maximumTarget: 100,
  ),
];

WorkoutGoalTemplate templateForGoalType(WorkoutGoalType type) {
  return workoutGoalTemplates.singleWhere((template) => template.type == type);
}
