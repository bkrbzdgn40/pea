import '../../domain/models/user_workout_goal.dart';

abstract interface class WorkoutGoalRepository {
  Future<List<UserWorkoutGoal>> listGoals({required String ownerId});

  Future<void> activateGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required double targetValue,
    required DateTime now,
  });

  Future<void> deleteAllGoals({required String ownerId});

  Future<void> pauseGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required DateTime now,
  });
}
