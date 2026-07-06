import '../domain/models/exercise_config.dart';
import '../domain/models/exercise_type.dart';
import 'exercise_catalog.dart';

/// Resolves the analysis config for the active exercise.
class ExerciseConfigResolver {
  const ExerciseConfigResolver([this._catalog = const ExerciseCatalog()]);

  final ExerciseCatalog _catalog;

  ExerciseConfig resolve(ExerciseType activeExercise) {
    final definition = _catalog.definitionFor(activeExercise);
    if (definition.isAnalysisSupported &&
        definition.configExercise == ExerciseType.squat) {
      return ExerciseConfig.squat();
    }

    assert(
      false,
      'Unsupported active analysis exercise reached config resolution: '
      '$activeExercise',
    );
    if (definition.configExercise == ExerciseType.squat) {
      return ExerciseConfig.squat();
    }

    return ExerciseConfig.squat();
  }
}
