import '../domain/models/exercise_type.dart';
import 'engine_kind.dart';
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
      engineKind: EngineKind.rangeRep,
      configAssetPath: 'assets/config/exercises/squat.json',
    ),
    ExerciseDefinition(
      type: ExerciseType.plank,
      id: ExerciseType.plank.id,
      title: ExerciseType.plank.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
      engineKind: EngineKind.hold,
    ),
    ExerciseDefinition(
      type: ExerciseType.lunge,
      id: ExerciseType.lunge.id,
      title: ExerciseType.lunge.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
      engineKind: EngineKind.alternatingRep,
    ),
    ExerciseDefinition(
      type: ExerciseType.pushUp,
      id: ExerciseType.pushUp.id,
      title: ExerciseType.pushUp.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
      engineKind: EngineKind.rangeRep,
    ),
    ExerciseDefinition(
      type: ExerciseType.sitUp,
      id: ExerciseType.sitUp.id,
      title: ExerciseType.sitUp.title,
      isAnalysisSupported: false,
      activeAnalysisExercise: ExerciseType.squat,
      configExercise: ExerciseType.squat,
      engineKind: EngineKind.rangeRep,
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
    return _fallbackDefinition();
  }

  ExerciseDefinition? definitionForIdOrNull(String id) {
    for (final definition in _definitions) {
      if (definition.id == id) {
        return definition;
      }
    }

    assert(false, 'Missing exercise definition for id: $id');
    return null;
  }

  ExerciseDefinition _fallbackDefinition() {
    for (final definition in _definitions) {
      if (definition.type == ExerciseType.squat) {
        return definition;
      }
    }

    throw StateError(
      'ExerciseCatalog must include a squat fallback definition.',
    );
  }
}
