import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/push_up_range_rep_analysis_extension.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_exercise_analysis_extension_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('RangeRep extension readiness', () {
    const catalog = ExerciseCatalog();
    const extensionFactory = RangeRepExerciseAnalysisExtensionFactory();

    test(
      'all supported range-rep exercises declare the current engine contract',
      () {
        final definitions = catalog.definitions.where(
          (definition) =>
              definition.isAnalysisSupported &&
              definition.engineKind == EngineKind.rangeRep,
        );

        expect(definitions, isNotEmpty);
        for (final definition in definitions) {
          final contract = definition.analysisRangeRepContract;
          final configFile = File(definition.analysisConfigAssetPath);
          expect(
            configFile.existsSync(),
            isTrue,
            reason: '${definition.id} must declare an existing config asset',
          );
          final config = ExerciseConfig.fromMap(
            jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>,
          );

          expect(
            () => const AnalysisEngineFactory().createRangeRep(
              config: config,
              rangeRepContract: contract,
            ),
            returnsNormally,
          );

          final landmarkRequirements = const ExerciseLandmarkRequirements()
              .resolve(
                config: config,
                engineKind: EngineKind.rangeRep,
                rangeRepContract: contract,
                side: contract.sideMode == RangeRepSideMode.selectedSide
                    ? RangeRepSide.left
                    : null,
              );
          expect(
            landmarkRequirements.requiredLandmarks,
            isNotEmpty,
            reason: '${definition.id} must resolve analysis landmarks',
          );

          expect(
            contract.supportedPhases,
            containsAll(<RangeRepPhase>{
              RangeRepPhase.descending,
              RangeRepPhase.peak,
              RangeRepPhase.ascending,
            }),
            reason: '${definition.id} must support the current phase topology',
          );
          expect(
            contract.supportsSignal(RangeRepSignal.primaryMetric),
            isTrue,
            reason: '${definition.id} needs a primary detection metric',
          );
          expect(
            contract.supportsSignal(RangeRepSignal.formMetric),
            isTrue,
            reason: '${definition.id} needs the current form metric carrier',
          );
          expect(
            RangeRepPrimaryMetricDirection.values,
            contains(contract.primaryMetricDirection),
            reason:
                '${definition.id} must declare an explicit metric direction',
          );
          switch (contract.primaryMetricDirection) {
            case RangeRepPrimaryMetricDirection.decreasingToPeak:
              expect(
                config.thresholdNeutral,
                greaterThan(config.thresholdActive),
              );
              expect(config.thresholdActive, greaterThan(config.thresholdPeak));
            case RangeRepPrimaryMetricDirection.increasingToPeak:
              expect(config.thresholdNeutral, lessThan(config.thresholdActive));
              expect(config.thresholdActive, lessThan(config.thresholdPeak));
              expect(
                config.targetMaxAngle,
                isNotNull,
                reason:
                    '${definition.id} increasing metrics need targetMaxAngle',
              );
              expect(
                definition
                    .analysisRangeRepValidationConfig
                    .minAcceptableRomDelta,
                isNotNull,
                reason:
                    '${definition.id} increasing metrics must validate ROM as delta',
              );
          }
          expect(
            () => extensionFactory.create(contract.extensionProfile),
            returnsNormally,
          );
        }
      },
    );

    test('toward-peak muscle action metadata matches exercise mechanics', () {
      const concentricTowardPeak = <ExerciseType>{
        ExerciseType.sitUp,
        ExerciseType.bicepsCurl,
        ExerciseType.lyingLegRaise,
        ExerciseType.lateralRaise,
        ExerciseType.shoulderPress,
        ExerciseType.calfRaise,
        ExerciseType.frontRaise,
        ExerciseType.gluteBridge,
        ExerciseType.jumpingJack,
      };

      for (final definition in catalog.definitions.where(
        (definition) =>
            definition.isAnalysisSupported &&
            definition.engineKind == EngineKind.rangeRep,
      )) {
        final expected = concentricTowardPeak.contains(definition.type)
            ? RangeRepTowardPeakMuscleAction.concentric
            : RangeRepTowardPeakMuscleAction.eccentric;
        expect(
          definition.analysisRangeRepContract.towardPeakMuscleAction,
          expected,
          reason: definition.id,
        );
      }
    });

    test('extension selection is semantic, not contract identity based', () {
      final copiedPushUpContract = RangeRepContract(
        supportedPhases: RangeRepContracts.pushUp.supportedPhases,
        supportedSignals: RangeRepContracts.pushUp.supportedSignals,
        signalRoles: RangeRepContracts.pushUp.signalRoles,
        poseAcceptanceRequiredSignals:
            RangeRepContracts.pushUp.poseAcceptanceRequiredSignals,
        formThresholdCalibrationPolicy:
            RangeRepContracts.pushUp.formThresholdCalibrationPolicy,
        sideMode: RangeRepContracts.pushUp.sideMode,
        primaryMetricKind: RangeRepContracts.pushUp.primaryMetricKind,
        primaryMetricDirection: RangeRepContracts.pushUp.primaryMetricDirection,
        towardPeakMuscleAction: RangeRepContracts.pushUp.towardPeakMuscleAction,
        extensionProfile: RangeRepContracts.pushUp.extensionProfile,
      );

      expect(
        identical(copiedPushUpContract, RangeRepContracts.pushUp),
        isFalse,
      );
      expect(
        extensionFactory.create(copiedPushUpContract.extensionProfile),
        isA<PushUpRangeRepExerciseAnalysisExtension>(),
      );
    });

    test('engine factory accepts increasing metric direction explicitly', () {
      final contract = RangeRepContract(
        supportedPhases: const <RangeRepPhase>{
          RangeRepPhase.descending,
          RangeRepPhase.peak,
          RangeRepPhase.ascending,
        },
        supportedSignals: const <RangeRepSignal>{
          RangeRepSignal.primaryMetric,
          RangeRepSignal.formMetric,
        },
        signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
          RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
            AnalysisSignalRole.detection,
          },
          RangeRepSignal.formMetric: <AnalysisSignalRole>{
            AnalysisSignalRole.validation,
          },
        },
        primaryMetricDirection: RangeRepPrimaryMetricDirection.increasingToPeak,
      );
      final config = ExerciseConfig(
        name: 'Increasing metric exercise',
        primaryJoint: PoseLandmarkType.leftElbow,
        joint1: PoseLandmarkType.leftShoulder,
        joint2: PoseLandmarkType.leftWrist,
        thresholdNeutral: 20,
        thresholdActive: 60,
        thresholdPeak: 120,
        targetMaxAngle: 160,
      );

      expect(
        () => const AnalysisEngineFactory().createRangeRep(
          config: config,
          rangeRepContract: contract,
        ),
        returnsNormally,
      );
    });
  });
}
