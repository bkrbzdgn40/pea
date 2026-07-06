import 'exercise_catalog.dart';
import '../domain/models/exercise_type.dart';

/// Resolves which exercise the current analysis pipeline can actually run.
class ExerciseAnalysisResolver {
  const ExerciseAnalysisResolver([this._catalog = const ExerciseCatalog()]);

  final ExerciseCatalog _catalog;

  ExerciseType resolveActiveExercise(ExerciseType selectedExercise) {
    return _catalog
        .definitionFor(selectedExercise)
        .activeAnalysisExercise;
  }
}
