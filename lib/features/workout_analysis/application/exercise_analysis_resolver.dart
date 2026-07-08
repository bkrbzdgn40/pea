import 'exercise_catalog.dart';
import '../domain/models/exercise_type.dart';

/// Resolves which exercise the current analysis pipeline can actually run.
class ExerciseAnalysisResolver {
  const ExerciseAnalysisResolver([this._catalog = const ExerciseCatalog()]);

  final ExerciseCatalog _catalog;

  ExerciseType? resolveActiveExercise(ExerciseType? selectedExercise) {
    if (selectedExercise == null) {
      return null;
    }

    final definition = _catalog.definitionFor(selectedExercise);
    if (!definition.isAnalysisSupported) {
      return null;
    }

    return definition.analysisExercise;
  }
}
