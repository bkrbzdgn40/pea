import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/goals/application/goal_progress_calculator.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_statistics.dart';

void main() {
  const calculator = GoalProgressCalculator();
  final statistics = WorkoutStatistics(
    snapshotSessionCount: 8,
    snapshotTotalReps: 210,
    currentWeekAnalysisCount: 3,
    currentWeekRepCount: 75,
    chronologicalScoreSamples: [],
    averageScore: 82.5,
    bestScore: 91,
    exerciseSessionCounts: {},
  );

  test('maps each goal type to its canonical statistic', () {
    expect(
      calculator.currentValue(
        type: WorkoutGoalType.weeklySessions,
        statistics: statistics,
      ),
      3,
    );
    expect(
      calculator.currentValue(
        type: WorkoutGoalType.weeklyReps,
        statistics: statistics,
      ),
      75,
    );
    expect(
      calculator.currentValue(
        type: WorkoutGoalType.averageScore,
        statistics: statistics,
      ),
      82.5,
    );
  });
}
