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

    test('assigns the fast live-analysis profile only to Jumping Jack', () {
      expect(
        catalog.definitionFor(ExerciseType.jumpingJack).analysisFrameInterval,
        const Duration(milliseconds: 50),
      );

      for (final definition in catalog.definitions.where(
        (definition) => definition.type != ExerciseType.jumpingJack,
      )) {
        expect(
          definition.analysisFrameInterval,
          const Duration(milliseconds: 100),
          reason: definition.id,
        );
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

    test('declares stability capability and summary for hold exercises', () {
      for (final definition in catalog.definitions.where(
        (definition) => definition.trackingType == ExerciseTrackingType.hold,
      )) {
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.stability),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.declaresMetric(ExerciseMetricId.stability),
          isTrue,
          reason: definition.id,
        );
        expect(
          definition.includesSummaryField(
            ExerciseSessionSummaryField.stabilityScore,
          ),
          isTrue,
          reason: definition.id,
        );
      }

      for (final definition in catalog.definitions.where(
        (definition) => definition.trackingType != ExerciseTrackingType.hold,
      )) {
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.stability),
          isFalse,
          reason: definition.id,
        );
        expect(
          definition.declaresMetric(ExerciseMetricId.stability),
          isFalse,
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
      expect(lunge.declaresMetric(ExerciseMetricId.asymmetryScore), isTrue);
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
        expect(
          definition.declaresMetric(ExerciseMetricId.asymmetryScore),
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
        ExerciseType.crunch: ExerciseMovementPattern.trunkFlexion,
        ExerciseType.reverseCrunch: ExerciseMovementPattern.trunkFlexion,
        ExerciseType.bicepsCurl: ExerciseMovementPattern.elbowFlexion,
        ExerciseType.lyingLegRaise: ExerciseMovementPattern.hipFlexion,
        ExerciseType.bentKneeLegRaise: ExerciseMovementPattern.hipFlexion,
        ExerciseType.standingHamstringCurl: ExerciseMovementPattern.kneeFlexion,
        ExerciseType.standingHipAbduction: ExerciseMovementPattern.hipAbduction,
        ExerciseType.tricepsDip: ExerciseMovementPattern.elbowExtension,
        ExerciseType.romanianDeadlift: ExerciseMovementPattern.hipHinge,
        ExerciseType.goodMorning: ExerciseMovementPattern.hipHinge,
        ExerciseType.lateralRaise: ExerciseMovementPattern.shoulderAbduction,
        ExerciseType.shoulderPress: ExerciseMovementPattern.verticalPush,
        ExerciseType.overheadTricepsExtension:
            ExerciseMovementPattern.elbowExtension,
        ExerciseType.uprightRow: ExerciseMovementPattern.shoulderAbduction,
        ExerciseType.calfRaise: ExerciseMovementPattern.anklePlantarFlexion,
        ExerciseType.frontRaise: ExerciseMovementPattern.shoulderFlexion,
        ExerciseType.gluteBridge: ExerciseMovementPattern.hipExtension,
        ExerciseType.wallSit: ExerciseMovementPattern.squatHold,
        ExerciseType.sidePlank: ExerciseMovementPattern.sideCoreHold,
        ExerciseType.jumpingJack: ExerciseMovementPattern.fullBodyAbduction,
        ExerciseType.standingHipExtension: ExerciseMovementPattern.hipExtension,
        ExerciseType.standingKneeRaise: ExerciseMovementPattern.hipFlexion,
        ExerciseType.standingStraightLegRaise:
            ExerciseMovementPattern.hipFlexion,
        ExerciseType.vUp: ExerciseMovementPattern.trunkFlexion,
        ExerciseType.frogPump: ExerciseMovementPattern.hipExtension,
        ExerciseType.lyingTricepsExtension:
            ExerciseMovementPattern.elbowExtension,
        ExerciseType.floorChestPress: ExerciseMovementPattern.horizontalPush,
        ExerciseType.yRaise: ExerciseMovementPattern.shoulderAbduction,
      };

      expect(expectedPatterns.keys, unorderedEquals(ExerciseType.values));
      for (final entry in expectedPatterns.entries) {
        expect(
          catalog.definitionFor(entry.key).movementPattern,
          entry.value,
          reason: entry.key.id,
        );
      }
    });

    test('registers the Day 11 exercise package on the intended engines', () {
      final rangeRepExpectations = <ExerciseType, RangeRepContract>{
        ExerciseType.calfRaise: RangeRepContracts.calfRaise,
        ExerciseType.frontRaise: RangeRepContracts.frontRaise,
        ExerciseType.gluteBridge: RangeRepContracts.gluteBridge,
        ExerciseType.jumpingJack: RangeRepContracts.jumpingJack,
      };

      for (final entry in rangeRepExpectations.entries) {
        final definition = catalog.definitionFor(entry.key);
        expect(definition.analysisEngineKind, EngineKind.rangeRep);
        expect(definition.analysisRangeRepContract, same(entry.value));
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.tempo),
          isTrue,
        );
      }

      final gluteBridge = catalog.definitionFor(ExerciseType.gluteBridge);
      expect(
        gluteBridge.declaresFeedbackRule(
          ExerciseFeedbackRuleId.movementProgress,
        ),
        isTrue,
      );
      expect(
        gluteBridge.declaresFeedbackRule(ExerciseFeedbackRuleId.formCorrection),
        isFalse,
      );

      final wallSit = catalog.definitionFor(ExerciseType.wallSit);
      expect(wallSit.analysisEngineKind, EngineKind.hold);
      expect(wallSit.analysisHoldContract, same(HoldContracts.wallSit));
      expect(
        wallSit.usesAnalysisEngine(ExerciseAnalysisEngine.stability),
        isTrue,
      );

      final sidePlank = catalog.definitionFor(ExerciseType.sidePlank);
      expect(sidePlank.analysisEngineKind, EngineKind.hold);
      expect(sidePlank.analysisHoldContract, same(HoldContracts.sidePlank));
      expect(
        sidePlank.usesAnalysisEngine(ExerciseAnalysisEngine.stability),
        isTrue,
      );
    });

    test('registers package two on the existing RangeRep engine', () {
      final expectations = <ExerciseType, RangeRepContract>{
        ExerciseType.standingHipExtension:
            RangeRepContracts.standingHipExtension,
        ExerciseType.standingKneeRaise: RangeRepContracts.standingKneeRaise,
        ExerciseType.standingStraightLegRaise:
            RangeRepContracts.standingStraightLegRaise,
        ExerciseType.vUp: RangeRepContracts.vUp,
        ExerciseType.frogPump: RangeRepContracts.frogPump,
        ExerciseType.lyingTricepsExtension:
            RangeRepContracts.lyingTricepsExtension,
        ExerciseType.floorChestPress: RangeRepContracts.floorChestPress,
        ExerciseType.yRaise: RangeRepContracts.yRaise,
      };

      for (final entry in expectations.entries) {
        final definition = catalog.definitionFor(entry.key);
        expect(definition.analysisEngineKind, EngineKind.rangeRep);
        expect(definition.analysisRangeRepContract, same(entry.value));
        expect(
          definition.usesAnalysisEngine(ExerciseAnalysisEngine.tempo),
          isTrue,
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

    test('enables Good Morning as a selected-side hip-hinge range rep', () {
      final definition = catalog.definitionFor(ExerciseType.goodMorning);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/good_morning.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.goodMorning),
      );
      expect(
        definition.analysisRangeRepContract.sideMode,
        RangeRepSideMode.selectedSide,
      );
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        25.0,
      );
    });

    test('registers the seven-exercise range-rep package', () {
      final expectations = <ExerciseType, RangeRepContract>{
        ExerciseType.crunch: RangeRepContracts.crunch,
        ExerciseType.reverseCrunch: RangeRepContracts.reverseCrunch,
        ExerciseType.bentKneeLegRaise: RangeRepContracts.bentKneeLegRaise,
        ExerciseType.standingHamstringCurl:
            RangeRepContracts.standingHamstringCurl,
        ExerciseType.standingHipAbduction:
            RangeRepContracts.standingHipAbduction,
        ExerciseType.overheadTricepsExtension:
            RangeRepContracts.overheadTricepsExtension,
        ExerciseType.uprightRow: RangeRepContracts.uprightRow,
      };

      for (final entry in expectations.entries) {
        final definition = catalog.definitionFor(entry.key);
        expect(definition.analysisEngineKind, EngineKind.rangeRep);
        expect(definition.analysisRangeRepContract, same(entry.value));
        expect(
          definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
          isNotNull,
          reason: entry.key.id,
        );
      }

      expect(
        catalog
            .definitionFor(ExerciseType.overheadTricepsExtension)
            .analysisRangeRepContract
            .sideMode,
        RangeRepSideMode.bilateral,
      );
      expect(
        catalog
            .definitionFor(ExerciseType.uprightRow)
            .analysisRangeRepContract
            .sideMode,
        RangeRepSideMode.bilateral,
      );
    });

    test('declares side-only camera support for side-view exercises', () {
      for (final type in const <ExerciseType>[
        ExerciseType.squat,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
        ExerciseType.crunch,
        ExerciseType.reverseCrunch,
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.lunge,
        ExerciseType.lyingLegRaise,
        ExerciseType.bentKneeLegRaise,
        ExerciseType.standingHamstringCurl,
        ExerciseType.tricepsDip,
        ExerciseType.romanianDeadlift,
        ExerciseType.goodMorning,
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
      'declares front-only camera support for the new front-view exercises',
      () {
        for (final type in const <ExerciseType>[
          ExerciseType.bicepsCurl,
          ExerciseType.lateralRaise,
          ExerciseType.shoulderPress,
          ExerciseType.standingHipAbduction,
          ExerciseType.overheadTricepsExtension,
          ExerciseType.uprightRow,
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
        ExerciseType.goodMorning,
        ExerciseType.crunch,
        ExerciseType.reverseCrunch,
        ExerciseType.bentKneeLegRaise,
        ExerciseType.standingHamstringCurl,
        ExerciseType.standingHipAbduction,
        ExerciseType.lateralRaise,
        ExerciseType.shoulderPress,
        ExerciseType.overheadTricepsExtension,
        ExerciseType.uprightRow,
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
