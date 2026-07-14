import '../domain/models/hold_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_definition.dart';

/// Central exercise metadata source for analysis capability.
class ExerciseCatalog {
  const ExerciseCatalog();

  static final List<ExerciseDefinition> _definitions = [
    ExerciseDefinition.supported(
      type: ExerciseType.squat,
      id: ExerciseType.squat.id,
      title: ExerciseType.squat.title,
      engineKind: EngineKind.rangeRep,
      configAssetPath: 'assets/config/exercises/squat.json',
      rangeRepContract: RangeRepContracts.squat,
    ),
    ExerciseDefinition.supported(
      type: ExerciseType.plank,
      id: ExerciseType.plank.id,
      title: ExerciseType.plank.title,
      engineKind: EngineKind.hold,
      configAssetPath: 'assets/config/exercises/plank.json',
      holdContract: HoldContracts.plankFamily,
    ),
    ExerciseDefinition.unsupported(
      type: ExerciseType.lunge,
      id: ExerciseType.lunge.id,
      title: ExerciseType.lunge.title,
    ),
    ExerciseDefinition.supported(
      type: ExerciseType.pushUp,
      id: ExerciseType.pushUp.id,
      title: ExerciseType.pushUp.title,
      engineKind: EngineKind.rangeRep,
      configAssetPath: 'assets/config/exercises/push_up.json',
      rangeRepContract: RangeRepContracts.pushUp,
    ),
    ExerciseDefinition.unsupported(
      type: ExerciseType.sitUp,
      id: ExerciseType.sitUp.id,
      title: ExerciseType.sitUp.title,
    ),
  ];

  List<ExerciseDefinition> get definitions => _definitions;

  ExerciseDefinition definitionFor(ExerciseType type) {
    for (final definition in _definitions) {
      if (definition.type == type) {
        return definition;
      }
    }

    throw StateError('Missing exercise definition for: $type');
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
}
