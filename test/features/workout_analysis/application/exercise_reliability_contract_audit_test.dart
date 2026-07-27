import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  const requirements = ExerciseLandmarkRequirements();
  const metricsExtractor = ExerciseMetricsExtractor();
  final fullyObservedPose = Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (var index = 0; index < PoseLandmarkType.values.length; index++)
        PoseLandmarkType.values[index]: buildLandmark(
          PoseLandmarkType.values[index],
          index * 3.0,
          (index * index + index % 3).toDouble(),
        ),
    },
  );

  const reliabilityBaselineTypes = <ExerciseType>{
    ExerciseType.squat,
    ExerciseType.plank,
    ExerciseType.hollowHold,
    ExerciseType.lunge,
    ExerciseType.pushUp,
    ExerciseType.sitUp,
    ExerciseType.crunch,
    ExerciseType.reverseCrunch,
    ExerciseType.bicepsCurl,
    ExerciseType.lyingLegRaise,
    ExerciseType.bentKneeLegRaise,
    ExerciseType.standingHamstringCurl,
    ExerciseType.standingHipAbduction,
    ExerciseType.tricepsDip,
    ExerciseType.romanianDeadlift,
    ExerciseType.goodMorning,
    ExerciseType.lateralRaise,
    ExerciseType.shoulderPress,
    ExerciseType.overheadTricepsExtension,
    ExerciseType.uprightRow,
    ExerciseType.calfRaise,
    ExerciseType.frontRaise,
    ExerciseType.gluteBridge,
    ExerciseType.wallSit,
    ExerciseType.sidePlank,
    ExerciseType.jumpingJack,
    ExerciseType.standingHipExtension,
    ExerciseType.standingKneeRaise,
    ExerciseType.standingStraightLegRaise,
    ExerciseType.vUp,
    ExerciseType.frogPump,
    ExerciseType.lyingTricepsExtension,
    ExerciseType.floorChestPress,
    ExerciseType.yRaise,
  };

  group('Exercise reliability contract audit', () {
    test('freezes the current 34-exercise supported reliability baseline', () {
      final supportedTypes = catalog.definitions
          .where((definition) => definition.isAnalysisSupported)
          .map((definition) => definition.type)
          .toSet();

      expect(supportedTypes, reliabilityBaselineTypes);
      expect(supportedTypes, hasLength(34));
      expect(
        catalog.definitions
            .where(
              (definition) =>
                  definition.analysisEngineKind == EngineKind.rangeRep,
            )
            .length,
        30,
      );
      expect(
        catalog.definitions
            .where(
              (definition) => definition.analysisEngineKind == EngineKind.hold,
            )
            .length,
        4,
      );
    });

    test('every supported catalog definition loads its real asset and passes '
        'production engine contract validation', () {
      final configPaths = <String>{};

      for (final definition in catalog.definitions) {
        final configPath = definition.analysisConfigAssetPath;
        final config = loadExerciseConfig(configPath);

        expect(configPaths.add(configPath), isTrue, reason: definition.id);
        expect(config.name.trim(), isNotEmpty, reason: definition.id);
        expect(
          definition.analysisCameraViewContract.supportedViews,
          isNotEmpty,
          reason: definition.id,
        );
        expect(
          definition.analysisCameraViewContract.preferredViews,
          hasLength(1),
          reason: definition.id,
        );

        switch (definition.analysisEngineKind) {
          case EngineKind.rangeRep:
            expect(
              () => factory.createRangeRep(
                config: config,
                rangeRepContract: definition.analysisRangeRepContract,
              ),
              returnsNormally,
              reason: definition.id,
            );
            break;
          case EngineKind.hold:
            expect(
              () => factory.createHold(
                config: config,
                holdContract: definition.analysisHoldContract,
              ),
              returnsNormally,
              reason: definition.id,
            );
            break;
          case EngineKind.alternatingRep:
            fail(
              '${definition.id} uses EngineKind.alternatingRep, which is not '
              'a supported primary runtime engine in the current catalog.',
            );
        }
      }

      expect(configPaths, hasLength(reliabilityBaselineTypes.length));
    });

    test(
      'range-rep definitions keep signal, validation, and landmark contracts '
      'internally resolvable',
      () {
        for (final definition in catalog.definitions.where(
          (definition) => definition.analysisEngineKind == EngineKind.rangeRep,
        )) {
          final config = loadExerciseConfig(definition.analysisConfigAssetPath);
          final contract = definition.analysisRangeRepContract;
          final validation = definition.analysisRangeRepValidationConfig;

          expect(
            contract.poseAcceptanceRequiredSignals.difference(
              contract.supportedSignals,
            ),
            isEmpty,
            reason: definition.id,
          );
          expect(
            contract.poseAcceptanceRequiredSignals,
            contains(RangeRepSignal.primaryMetric),
            reason: definition.id,
          );
          expect(
            validation.minDescentMillis,
            greaterThan(0),
            reason: definition.id,
          );
          expect(
            validation.minAscentMillis,
            greaterThan(0),
            reason: definition.id,
          );

          final minRomDelta = validation.minAcceptableRomDelta;
          if (contract.primaryMetricDirection ==
              RangeRepPrimaryMetricDirection.increasingToPeak) {
            expect(
              minRomDelta,
              isNotNull,
              reason:
                  '${definition.id} increases toward peak, so absolute '
                  'minimum-angle validation is not direction-safe.',
            );
          }
          if (minRomDelta != null) {
            expect(minRomDelta, greaterThan(0), reason: definition.id);
          }

          final extractedMetrics = metricsExtractor.extract(
            fullyObservedPose,
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: contract,
          );
          expect(
            extractedMetrics.leftRangeRepMetrics.hasPrimaryAngle,
            isTrue,
            reason: definition.id,
          );
          expect(
            extractedMetrics.rightRangeRepMetrics.hasPrimaryAngle,
            isTrue,
            reason: definition.id,
          );
          if (contract.sideMode == RangeRepSideMode.bilateral) {
            expect(
              extractedMetrics.bilateralRangeRepMetrics?.hasPrimaryAngle,
              isTrue,
              reason: definition.id,
            );
          }

          final supportedBySide = <RangeRepSide, Set<Object>>{};
          for (final side in RangeRepSide.values) {
            final supported = requirements.resolve(
              config: config,
              engineKind: EngineKind.rangeRep,
              rangeRepContract: contract,
              rangeRepSignalSet: RangeRepSignalSet.supportedAnalysis,
              side: side,
            );
            final poseAcceptance = requirements.resolve(
              config: config,
              engineKind: EngineKind.rangeRep,
              rangeRepContract: contract,
              rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
              side: side,
            );

            expect(
              supported.requiredLandmarks,
              isNotEmpty,
              reason: definition.id,
            );
            expect(
              supported.requiredSegments,
              isNotEmpty,
              reason: definition.id,
            );
            expect(
              poseAcceptance.requiredLandmarks,
              isNotEmpty,
              reason: definition.id,
            );
            expect(
              supported.requiredLandmarks.containsAll(
                poseAcceptance.requiredLandmarks,
              ),
              isTrue,
              reason: definition.id,
            );
            supportedBySide[side] = supported.requiredLandmarks.cast<Object>();
          }

          if (contract.sideMode == RangeRepSideMode.bilateral) {
            final bilateral = requirements.resolve(
              config: config,
              engineKind: EngineKind.rangeRep,
              rangeRepContract: contract,
            );
            expect(
              bilateral.requiredLandmarks.containsAll(
                supportedBySide[RangeRepSide.left]!,
              ),
              isTrue,
              reason: definition.id,
            );
            expect(
              bilateral.requiredLandmarks.containsAll(
                supportedBySide[RangeRepSide.right]!,
              ),
              isTrue,
              reason: definition.id,
            );
          }
        }
      },
    );

    test('Romanian Deadlift pose acceptance does not require the ankle-only '
        'technique carrier', () {
      final config = loadExerciseConfig(
        'assets/config/exercises/romanian_deadlift.json',
      );
      final contract = RangeRepContracts.romanianDeadlift;

      final supported = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: contract,
        rangeRepSignalSet: RangeRepSignalSet.supportedAnalysis,
        side: RangeRepSide.left,
      );
      final poseAcceptance = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: contract,
        rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
        side: RangeRepSide.left,
      );

      expect(supported.requiredLandmarks, contains(PoseLandmarkType.leftAnkle));
      expect(
        poseAcceptance.requiredLandmarks,
        containsAll(<PoseLandmarkType>[
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        ]),
      );
      expect(
        poseAcceptance.requiredLandmarks,
        isNot(contains(PoseLandmarkType.leftAnkle)),
      );
    });

    test('Good Morning preserves the hip-hinge landmark contract', () {
      final config = loadExerciseConfig(
        'assets/config/exercises/good_morning.json',
      );
      final contract = RangeRepContracts.goodMorning;

      final supported = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: contract,
        rangeRepSignalSet: RangeRepSignalSet.supportedAnalysis,
        side: RangeRepSide.left,
      );
      final poseAcceptance = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: contract,
        rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
        side: RangeRepSide.left,
      );

      expect(supported.requiredLandmarks, contains(PoseLandmarkType.leftAnkle));
      expect(
        poseAcceptance.requiredLandmarks,
        containsAll(<PoseLandmarkType>[
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        ]),
      );
      expect(
        poseAcceptance.requiredLandmarks,
        isNot(contains(PoseLandmarkType.leftAnkle)),
      );
    });

    test('hold definitions resolve every required signal on both sides', () {
      for (final definition in catalog.definitions.where(
        (definition) => definition.analysisEngineKind == EngineKind.hold,
      )) {
        final config = loadExerciseConfig(definition.analysisConfigAssetPath);
        final contract = definition.analysisHoldContract;

        expect(contract.requiredSignals, isNotEmpty, reason: definition.id);

        for (final side in HoldSide.values) {
          final resolved = requirements.resolve(
            config: config,
            engineKind: EngineKind.hold,
            holdContract: contract,
            holdSide: side,
          );
          final extractedMetrics = metricsExtractor.extract(
            fullyObservedPose,
            config,
            engineKind: EngineKind.hold,
            holdContract: contract,
            holdSide: side,
          );

          expect(resolved.requiredLandmarks, isNotEmpty, reason: definition.id);
          for (final signal in contract.requiredSignals) {
            expect(
              extractedMetrics.holdSignalValues.hasValue(signal),
              isTrue,
              reason: '${definition.id}:${side.name}:${signal.name}',
            );
          }
          expect(
            resolved.requiredAngleTriplets,
            hasLength(contract.requiredSignals.length),
            reason: definition.id,
          );
          expect(resolved.requiredSegments, isNotEmpty, reason: definition.id);
        }
      }
    });
  });
}
