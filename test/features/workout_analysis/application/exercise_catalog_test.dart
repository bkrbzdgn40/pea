import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_definition_metadata.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
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

    test('declares complete centralized capabilities for every exercise', () {
      for (final definition in catalog.definitions) {
        expect(definition.analysisEngines, isNotEmpty, reason: definition.id);
        expect(definition.metricIds, isNotEmpty, reason: definition.id);
        expect(definition.feedbackRuleIds, isNotEmpty, reason: definition.id);
        expect(
          definition.sessionSummaryFields,
          isNotEmpty,
          reason: definition.id,
        );
      }
    });

    test('keeps tracking type aligned with the primary runtime engine', () {
      for (final definition in catalog.definitions) {
        switch (definition.analysisEngineKind) {
          case EngineKind.rangeRep:
            expect(
              definition.trackingType,
              ExerciseTrackingType.repetitions,
              reason: definition.id,
            );
            expect(
              definition.usesAnalysisEngine(ExerciseAnalysisEngine.rangeRep),
              isTrue,
              reason: definition.id,
            );
            break;
          case EngineKind.alternatingRep:
            expect(
              definition.trackingType,
              ExerciseTrackingType.repetitions,
              reason: definition.id,
            );
            expect(
              definition.usesAnalysisEngine(
                ExerciseAnalysisEngine.alternatingRep,
              ),
              isTrue,
              reason: definition.id,
            );
            break;
          case EngineKind.hold:
            expect(
              definition.trackingType,
              ExerciseTrackingType.hold,
              reason: definition.id,
            );
            expect(
              definition.usesAnalysisEngine(ExerciseAnalysisEngine.hold),
              isTrue,
              reason: definition.id,
            );
            break;
        }
      }
    });

    test('declares tempo capability and summary fields for rep exercises', () {
      for (final definition in catalog.definitions.where(
        (definition) =>
            definition.trackingType == ExerciseTrackingType.repetitions,
      )) {
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.tempo),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.declaresMetric(ExerciseMetricId.tempo),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.includesSummaryField(
            ExerciseSessionSummaryField.averageTempo,
          ),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.includesSummaryField(
            ExerciseSessionSummaryField.fastestRep,
          ),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.includesSummaryField(
            ExerciseSessionSummaryField.slowestRep,
          ),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.includesSummaryField(
            ExerciseSessionSummaryField.tempoConsistency,
          ),
          isTrue,
          reason: definition.id,
        );
      }
    });

    test('declares alternating-rep capability for the lunge family', () {
      final lunge = catalog.definitionFor(ExerciseType.lunge);

      expect(
        lunge.usesAnalysisEngine(ExerciseAnalysisEngine.alternatingRep),
        isTrue,
      );
      expect(lunge.usesAnalysisEngine(ExerciseAnalysisEngine.rangeRep), isTrue);
      expect(lunge.analysisEngineKind, EngineKind.rangeRep);
    });

    test('declares symmetry only for the alternating-capable lunge family', () {
      final lunge = catalog.definitionFor(ExerciseType.lunge);

      expect(lunge.usesAnalysisEngine(ExerciseAnalysisEngine.symmetry), isTrue);
      expect(lunge.declaresMetric(ExerciseMetricId.symmetry), isTrue);
      expect(
        lunge.includesSummaryField(ExerciseSessionSummaryField.asymmetryScore),
        isTrue,
      );

      for (final definition in catalog.definitions.where(
        (definition) => definition.type != ExerciseType.lunge,
      )) {
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.symmetry),
          isFalse,
          reason: definition.id,
        );
        expect(
          definition.declaresMetric(ExerciseMetricId.symmetry),
          isFalse,
          reason: definition.id,
        );
      }
    });

    test('declares canonical movement patterns in the central catalog', () {
      const expectedPatterns = <ExerciseType, ExerciseMovementPattern>{
        ExerciseType.squat: ExerciseMovementPattern.squat,
        ExerciseType.plank: ExerciseMovementPattern.coreHold,
        ExerciseType.hollowHold: ExerciseMovementPattern.coreHold,
        ExerciseType.lunge: ExerciseMovementPattern.lunge,
        ExerciseType.pushUp: ExerciseMovementPattern.horizontalPush,
        ExerciseType.sitUp: ExerciseMovementPattern.trunkFlexion,
        ExerciseType.bicepsCurl: ExerciseMovementPattern.elbowFlexion,
        ExerciseType.lyingLegRaise: ExerciseMovementPattern.hipFlexion,
        ExerciseType.tricepsDip: ExerciseMovementPattern.elbowExtension,
        ExerciseType.romanianDeadlift: ExerciseMovementPattern.hipHinge,
        ExerciseType.lateralRaise: ExerciseMovementPattern.shoulderAbduction,
        ExerciseType.shoulderPress: ExerciseMovementPattern.verticalPush,
      };

      for (final entry in expectedPatterns.entries) {
        expect(
          catalog.definitionFor(entry.key).movementPattern,
          entry.value,
          reason: entry.key.id,
        );
      }
    });

    test('exposes immutable capability collections', () {
      final definition = catalog.definitionFor(ExerciseType.squat);

      expect(
        () => definition.analysisEngines.add(ExerciseAnalysisEngine.tempo),
        throwsUnsupportedError,
      );
      expect(
        () => definition.metricIds.add(ExerciseMetricId.holdDuration),
        throwsUnsupportedError,
      );
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
