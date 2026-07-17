import '../domain/models/hold_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_definition.dart';

/// Central exercise metadata source for analysis capability.
class ExerciseCatalog {
  const ExerciseCatalog();

  static final List<ExerciseDefinition> _definitions =
      List.unmodifiable(<ExerciseDefinition>[
        ExerciseDefinition.supported(
          type: ExerciseType.squat,
          engineKind: EngineKind.rangeRep,
          configAssetPath: 'assets/config/exercises/squat.json',
          rangeRepContract: RangeRepContracts.squat,
        ),
        ExerciseDefinition.supported(
          type: ExerciseType.plank,
          engineKind: EngineKind.hold,
          configAssetPath: 'assets/config/exercises/plank.json',
          holdContract: HoldContracts.plankFamily,
        ),
        ExerciseDefinition.supported(
          type: ExerciseType.hollowHold,
          engineKind: EngineKind.hold,
          configAssetPath: 'assets/config/exercises/hollow_hold.json',
          holdContract: HoldContracts.hollowHold,
        ),
        ExerciseDefinition.unsupported(type: ExerciseType.lunge),
        ExerciseDefinition.supported(
          type: ExerciseType.pushUp,
          engineKind: EngineKind.rangeRep,
          configAssetPath: 'assets/config/exercises/push_up.json',
          rangeRepContract: RangeRepContracts.pushUp,
        ),
        ExerciseDefinition.supported(
          type: ExerciseType.sitUp,
          engineKind: EngineKind.rangeRep,
          configAssetPath: 'assets/config/exercises/sit_up.json',
          rangeRepContract: RangeRepContracts.sitUp,
        ),
        ExerciseDefinition.supported(
          type: ExerciseType.bicepsCurl,
          engineKind: EngineKind.rangeRep,
          configAssetPath: 'assets/config/exercises/biceps_curl.json',
          rangeRepContract: RangeRepContracts.bicepsCurl,
        ),
      ]);

  static final Map<ExerciseType, ExerciseDefinition> _definitionsByType =
      _buildDefinitionsByType(_definitions);

  List<ExerciseDefinition> get definitions => _definitions;

  ExerciseDefinition definitionFor(ExerciseType type) {
    final definition = _definitionsByType[type];
    if (definition != null) {
      return definition;
    }

    throw StateError('Missing exercise definition for: $type');
  }

  ExerciseDefinition? definitionForIdOrNull(String id) {
    final type = ExerciseType.fromIdOrNull(id);
    if (type == null) {
      assert(false, 'Missing exercise definition for id: $id');
      return null;
    }

    return _definitionsByType[type];
  }

  static Map<ExerciseType, ExerciseDefinition> _buildDefinitionsByType(
    List<ExerciseDefinition> definitions,
  ) {
    final definitionsByType = <ExerciseType, ExerciseDefinition>{};
    for (final definition in definitions) {
      final previous = definitionsByType[definition.type];
      if (previous != null) {
        throw StateError(
          'Duplicate exercise definition registered for ${definition.type}.',
        );
      }
      definitionsByType[definition.type] = definition;
    }

    final missingTypes = ExerciseType.values
        .where((type) => !definitionsByType.containsKey(type))
        .map((type) => type.name)
        .toList(growable: false);
    if (missingTypes.isNotEmpty) {
      throw StateError(
        'Missing exercise definitions for: ${missingTypes.join(', ')}.',
      );
    }

    return Map.unmodifiable(definitionsByType);
  }
}
