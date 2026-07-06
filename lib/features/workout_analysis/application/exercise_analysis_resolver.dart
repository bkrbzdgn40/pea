import '../domain/models/exercise_type.dart';

/// Resolves which exercise the current analysis pipeline can actually run.
class ExerciseAnalysisResolver {
  const ExerciseAnalysisResolver();

  ExerciseType resolveActiveExercise(ExerciseType selectedExercise) {
    return switch (selectedExercise) {
      ExerciseType.squat => ExerciseType.squat,
      ExerciseType.plank ||
      ExerciseType.lunge ||
      ExerciseType.pushUp ||
      ExerciseType.sitUp => ExerciseType.squat,
    };
  }
}
