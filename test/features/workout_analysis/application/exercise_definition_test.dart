import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_definition.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

void main() {
  const catalog = ExerciseCatalog();

  group('ExerciseDefinition.analysisExercise', () {
    test('returns the canonical type for supported definitions', () {
      for (final type in const <ExerciseType>[
        ExerciseType.squat,
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
        ExerciseType.bicepsCurl,
        ExerciseType.lyingLegRaise,
        ExerciseType.tricepsDip,
        ExerciseType.romanianDeadlift,
        ExerciseType.lunge,
        ExerciseType.lateralRaise,
        ExerciseType.shoulderPress,
      ]) {
        final definition = catalog.definitionFor(type);

        expect(definition.analysisExercise, definition.type);
      }
    });
  });

  group('ExerciseDefinition.analysisCameraViewContract', () {
    test('returns the contract required by every supported definition', () {
      for (final definition in catalog.definitions.where(
        (definition) => definition.isAnalysisSupported,
      )) {
        expect(definition.cameraViewContract, isNotNull);
        expect(
          definition.analysisCameraViewContract,
          same(definition.cameraViewContract),
        );
      }
    });
  });

  group('ExerciseDefinition.analysisRangeRepValidationConfig', () {
    test('returns the config owned by a range-rep definition', () {
      final definition = catalog.definitionFor(ExerciseType.squat);

      expect(
        definition.analysisRangeRepValidationConfig,
        same(definition.rangeRepValidationConfig),
      );
    });

    test('throws StateError for a hold definition', () {
      final definition = catalog.definitionFor(ExerciseType.plank);

      expect(
        () => definition.analysisRangeRepValidationConfig,
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ExerciseDefinition.supported', () {
    test('requires range-rep definitions to provide a validation config', () {
      expect(
        () => ExerciseDefinition.supported(
          type: ExerciseType.squat,
          engineKind: EngineKind.rangeRep,
          configAssetPath: 'assets/config/exercises/squat.json',
          cameraViewContract: _sideViewContract(),
          rangeRepContract: RangeRepContracts.squat,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects hold definitions with a range-rep validation config', () {
      expect(
        () => ExerciseDefinition.supported(
          type: ExerciseType.plank,
          engineKind: EngineKind.hold,
          configAssetPath: 'assets/config/exercises/plank.json',
          cameraViewContract: _sideViewContract(),
          holdContract: HoldContracts.plankFamily,
          rangeRepValidationConfig: const RangeRepValidationConfig(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

CameraViewContract _sideViewContract() {
  return CameraViewContract(
    views: const <CameraView, CameraViewSupport>{
      CameraView.side: CameraViewSupport.preferred,
      CameraView.front: CameraViewSupport.unsupported,
    },
  );
}
