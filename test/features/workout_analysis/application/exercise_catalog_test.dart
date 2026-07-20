import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const catalog = ExerciseCatalog();

  group('ExerciseCatalog', () {
    test(
      'registers exactly one analysis definition per canonical exercise',
      () {
        final registeredTypes = catalog.definitions
            .map((definition) => definition.type)
            .toList(growable: false);

        expect(registeredTypes, unorderedEquals(ExerciseType.values));
        expect(registeredTypes.toSet(), hasLength(ExerciseType.values.length));
      },
    );

    test('derives id and title from the canonical exercise identity', () {
      for (final type in ExerciseType.values) {
        final definition = catalog.definitionFor(type);

        expect(definition.type, type);
        expect(definition.id, type.id);
        expect(definition.title, type.title);
      }
    });

    test(
      'definitionFor and definitionForIdOrNull resolve deterministically',
      () {
        for (final type in ExerciseType.values) {
          final byType = catalog.definitionFor(type);
          final byId = catalog.definitionForIdOrNull(type.id);

          expect(byId, same(byType));
        }
      },
    );

    test('keeps squat as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.squat);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.squat);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/squat.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.squat),
      );
    });

    test('keeps plank as a supported hold exercise', () {
      final definition = catalog.definitionFor(ExerciseType.plank);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.plank);
      expect(definition.analysisEngineKind, EngineKind.hold);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/plank.json',
      );
      expect(definition.analysisHoldContract, same(HoldContracts.plankFamily));
    });

    test('registers hollow hold as a supported hold exercise', () {
      final definition = catalog.definitionFor(ExerciseType.hollowHold);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.hollowHold);
      expect(definition.analysisEngineKind, EngineKind.hold);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/hollow_hold.json',
      );
      expect(definition.analysisHoldContract, same(HoldContracts.hollowHold));
    });

    test('keeps push-up as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.pushUp);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.pushUp);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/push_up.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.pushUp),
      );
    });

    test('enables sit-up as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.sitUp);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.sitUp);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/sit_up.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.sitUp),
      );
    });

    test('enables biceps curl as a supported bilateral range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.bicepsCurl);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.bicepsCurl);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/biceps_curl.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.bicepsCurl),
      );
      expect(
        definition.analysisRangeRepContract.sideMode,
        RangeRepSideMode.bilateral,
      );
    });

    test('enables stationary lunge as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.lunge);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.lunge);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/stationary_lunge.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.stationaryLunge),
      );
    });

    test('declares side-only camera support for side-view exercises', () {
      for (final type in const <ExerciseType>[
        ExerciseType.squat,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.lunge,
        ExerciseType.lyingLegRaise,
        ExerciseType.tricepsDip,
        ExerciseType.romanianDeadlift,
      ]) {
        final contract = catalog.definitionFor(type).analysisCameraViewContract;

        expect(
          contract.supportFor(CameraView.side),
          CameraViewSupport.preferred,
          reason: type.name,
        );
        expect(
          contract.supportFor(CameraView.front),
          CameraViewSupport.unsupported,
          reason: type.name,
        );
      }
    });

    test(
      'declares front-only camera support for bilateral upper-body exercises',
      () {
        for (final type in const <ExerciseType>[
          ExerciseType.bicepsCurl,
          ExerciseType.lateralRaise,
          ExerciseType.shoulderPress,
        ]) {
          final contract = catalog
              .definitionFor(type)
              .analysisCameraViewContract;

          expect(
            contract.supportFor(CameraView.side),
            CameraViewSupport.unsupported,
            reason: type.name,
          );
          expect(
            contract.supportFor(CameraView.front),
            CameraViewSupport.preferred,
            reason: type.name,
          );
        }
      },
    );

    test('stores Squat-specific validation timing', () {
      final definition = catalog.definitionFor(ExerciseType.squat);
      final config = definition.rangeRepValidationConfig;

      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(config, isNotNull);
      expect(config!.minAcceptableRomAngle, 110.0);
      expect(config.minDescentMillis, 300);
      expect(config.minAscentMillis, 250);
      expect(config.allowLowConfidenceOnCoverageLoss, isTrue);
    });

    test('stores Push-up-specific validation timing', () {
      final definition = catalog.definitionFor(ExerciseType.pushUp);
      final config = definition.rangeRepValidationConfig;

      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(config, isNotNull);
      expect(config!.minAcceptableRomAngle, 110.0);
      expect(config.minDescentMillis, 250);
      expect(config.minAscentMillis, 250);
      expect(config.allowLowConfidenceOnCoverageLoss, isTrue);
    });

    test('stores Sit-up-specific validation timing', () {
      final definition = catalog.definitionFor(ExerciseType.sitUp);
      final config = definition.rangeRepValidationConfig;

      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(config, isNotNull);
      expect(config!.minAcceptableRomAngle, 110.0);
      expect(config.minDescentMillis, 250);
      expect(config.minAscentMillis, 300);
      expect(config.allowLowConfidenceOnCoverageLoss, isTrue);
    });

    test('stores Biceps Curl-specific validation timing', () {
      final definition = catalog.definitionFor(ExerciseType.bicepsCurl);
      final config = definition.rangeRepValidationConfig;

      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(config, isNotNull);
      expect(config!.minAcceptableRomAngle, 110.0);
      expect(config.minDescentMillis, 250);
      expect(config.minAscentMillis, 250);
      expect(config.allowLowConfidenceOnCoverageLoss, isTrue);
    });

    test('new range-rep batch owns ROM-delta validation configs', () {
      for (final type in const <ExerciseType>[
        ExerciseType.lunge,
        ExerciseType.lyingLegRaise,
        ExerciseType.tricepsDip,
        ExerciseType.romanianDeadlift,
        ExerciseType.lateralRaise,
        ExerciseType.shoulderPress,
      ]) {
        final definition = catalog.definitionFor(type);
        final config = definition.analysisRangeRepValidationConfig;

        expect(
          definition.analysisEngineKind,
          EngineKind.rangeRep,
          reason: type.name,
        );
        expect(config.minAcceptableRomDelta, isNotNull, reason: type.name);
        expect(
          config.allowLowConfidenceOnCoverageLoss,
          isTrue,
          reason: type.name,
        );
      }
    });

    test('does not attach a range-rep validation config to hold exercises', () {
      for (final type in const <ExerciseType>[
        ExerciseType.plank,
        ExerciseType.hollowHold,
      ]) {
        final definition = catalog.definitionFor(type);

        expect(definition.rangeRepValidationConfig, isNull);
      }
    });
  });
}
