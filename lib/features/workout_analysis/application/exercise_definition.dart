import '../domain/models/exercise_type.dart';

/// In-memory exercise metadata that can later come from a JSON-backed source.
class ExerciseDefinition {
  const ExerciseDefinition({
    required this.type,
    required this.id,
    required this.title,
    required this.isAnalysisSupported,
    required this.activeAnalysisExercise,
    required this.configExercise,
  });

  final ExerciseType type;
  final String id;
  final String title;
  final bool isAnalysisSupported;
  final ExerciseType activeAnalysisExercise;
  final ExerciseType configExercise;
}
