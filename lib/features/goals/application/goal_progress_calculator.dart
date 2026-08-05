import '../../workout_analysis/application/workout_statistics.dart';
import '../domain/models/user_workout_goal.dart';

class GoalProgressCalculator {
  const GoalProgressCalculator();

  double currentValue({
    required WorkoutGoalType type,
    required WorkoutStatistics statistics,
  }) {
    return switch (type) {
      WorkoutGoalType.weeklySessions =>
        statistics.currentWeekAnalysisCount.toDouble(),
      WorkoutGoalType.weeklyReps => statistics.currentWeekRepCount.toDouble(),
      WorkoutGoalType.averageScore => statistics.averageScore,
    };
  }
}
