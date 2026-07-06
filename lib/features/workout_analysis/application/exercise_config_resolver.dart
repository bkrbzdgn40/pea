import '../domain/models/exercise_config.dart';
import '../domain/models/exercise_type.dart';

/// Resolves the analysis config for the active exercise.
class ExerciseConfigResolver {
  const ExerciseConfigResolver();

  ExerciseConfig resolve(ExerciseType activeExercise) {
    if (activeExercise == ExerciseType.squat) {
      return ExerciseConfig.squat();
    }

    assert(
      false,
      'Unsupported active analysis exercise reached config resolution: '
      '$activeExercise',
    );
    return ExerciseConfig.squat();
  }
}
