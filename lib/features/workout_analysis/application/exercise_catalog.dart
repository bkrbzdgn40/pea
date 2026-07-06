import '../domain/models/exercise_type.dart';
import 'exercise_definition.dart';

/// Central exercise metadata source for analysis capability and fallback policy.
class ExerciseCatalog {
  const ExerciseCatalog();

  static final List<ExerciseDefinition> _definitions = [
    ExerciseDefinition(
      type: ExerciseType.squat,
      id: ExerciseType.squat.id,
      title: ExerciseType.squat.title,
      isAnalysisSupported: true,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
    ),
    ExerciseDefinition(
      type: ExerciseType.plank,
      id: ExerciseType.plank.id,
      title: ExerciseType.plank.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
    ),
    ExerciseDefinition(
      type: ExerciseType.lunge,
      id: ExerciseType.lunge.id,
      title: ExerciseType.lunge.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
    ),
    ExerciseDefinition(
      type: ExerciseType.pushUp,
      id: ExerciseType.pushUp.id,
      title: ExerciseType.pushUp.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
    ),
    ExerciseDefinition(
      type: ExerciseType.sitUp,
      id: ExerciseType.sitUp.id,
      title: ExerciseType.sitUp.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
    ),
  ];

  List<ExerciseDefinition> get definitions => _definitions;

  ExerciseDefinition definitionFor(ExerciseType type) {
  for (final definition in _definitions) {
    if (definition.type == type) {
      return definition;
    }
  }

  assert(false, 'Missing exercise definition for: $type');
  return _definitions.first;
}
}
