import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  const extractor = ExerciseMetricsExtractor();
  final definition = catalog.definitionFor(ExerciseType.calfRaise);

  group('Calf Raise production contract', () {
    late TestFakeClock clock;
    late ExerciseConfig config;
    late RangeRepAnalysisEngine engine;

    setUp(() {
      clock = TestFakeClock();
      config = loadExerciseConfig(definition.analysisConfigAssetPath);
      engine = factory.createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      );
    });

    test('accepts a natural side-view standing setup as neutral', () {
      final metrics = extractor.extract(
        _calfRaisePose(primaryAngle: 115, kneeAngle: 175),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: definition.analysisRangeRepContract,
      );
      final sideMetrics = metrics.leftRangeRepMetrics;

      expect(config.thresholdNeutral, 120.0);
      expect(config.thresholdActive, 121.0);
      expect(config.thresholdPeak, 122.0);
      expect(config.targetMaxAngle, 125.0);
      expect(definition.analysisRangeRepContract.activeEntryMargin, 0.0);
      expect(definition.analysisRangeRepContract.peakEntryMargin, 0.0);
      expect(definition.analysisRangeRepContract.peakExitMargin, 1.0);
      expect(
        definition
            .analysisRangeRepContract
            .retainPeakEvidenceAcrossActiveTransition,
        isTrue,
      );
      expect(
        definition.analysisRangeRepContract.primaryMetricSmoothingWindow,
        1,
      );
      expect(
        definition.analysisRangeRepContract.neutralBaselineWindow,
        const Duration(milliseconds: 1500),
      );
      expect(
        definition.analysisRangeRepContract.neutralBaselineThresholdMargin,
        2.0,
      );
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        10.0,
      );
      expect(definition.analysisRangeRepValidationConfig.minDescentMillis, 0);
      expect(definition.analysisRangeRepValidationConfig.minAscentMillis, 0);
      expect(
        definition.analysisRangeRepValidationConfig.minTotalRepMillis,
        1500,
      );
      expect(config.rangeRepPhaseQuality!.minDescendingMillis, 0);
      expect(config.rangeRepPhaseQuality!.minAscendingMillis, 0);
      expect(
        definition.analysisRangeRepContract.extensionProfile,
        RangeRepExtensionProfile.calfRaise,
      );
      expect(
        definition
            .analysisRangeRepValidationConfig
            .invalidateOnPersistentFormBreak,
        isTrue,
      );
      expect(sideMetrics.primaryAngle, closeTo(115.0, 0.001));
      expect(sideMetrics.formMetric, closeTo(175.0, 0.001));
      expect(sideMetrics.primaryAngle, lessThan(config.thresholdNeutral));

      _sample(engine, clock, sideMetrics.primaryAngle);
      _sample(engine, clock, sideMetrics.primaryAngle);

      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 0);
    });

    test('counts the device-observed 123-degree heel-raise lifecycle', () {
      _sample(engine, clock, 105);
      _sample(engine, clock, 105);

      for (final metric in <double>[123, 123, 109, 109, 105, 105]) {
        _sample(engine, clock, metric);
      }
      final completed = _sample(engine, clock, 105);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.completedRepDetectionData, isNotNull);
      expect(completed.completedRepDetectionData!.primaryRom, 18.0);
    });

    test('counts the exact 123-degree boundary with 10-degree ROM', () {
      _sample(engine, clock, 113);
      _sample(engine, clock, 113);

      for (final metric in <double>[123, 123, 118, 118, 113, 113]) {
        _sample(engine, clock, metric);
      }
      final completed = _sample(engine, clock, 113);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.completedRepDetectionData, isNotNull);
      expect(completed.completedRepDetectionData!.primaryRom, 10.0);
    });

    test('does not count a small heel movement that never reaches peak', () {
      _sample(engine, clock, 115);
      _sample(engine, clock, 115);

      for (final metric in <double>[119, 121, 122, 119, 115, 115]) {
        _sample(engine, clock, metric);
      }

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('keeps the strict 122-degree threshold itself below peak', () {
      _sample(engine, clock, 115);
      _sample(engine, clock, 115);

      for (final metric in <double>[121, 122, 121, 119, 115, 115]) {
        _sample(engine, clock, metric);
      }

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('uses neutral history instead of the last threshold-edge sample', () {
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
      );

      RangeRepCoordinatorFrameResult? result;
      for (final metric in <double>[
        110,
        110,
        117,
        123,
        121,
        120,
        122,
        122,
        122,
        125,
        125,
        125,
        125,
        125,
        125,
        120,
        120,
        120,
        110,
        110,
        110,
      ]) {
        result = _processCoordinatorSample(
          coordinator,
          clock,
          primaryMetric: metric,
        );
      }

      expect(result, isNotNull);
      expect(result!.stateSnapshot.repCount, 1);
      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepSummaryPrimaryRom,
        15.0,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
        'valid',
      );
      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepValidationReasons,
        isEmpty,
      );
      expect(result.stateSnapshot.lastRepScore, 100.0);
    });

    test(
      'counts the device-observed sequence and reports sparse timing as low confidence',
      () {
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: definition.analysisRangeRepContract,
          rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
        );

        RangeRepCoordinatorFrameResult? result;
        for (final metric in <double>[
          105,
          105,
          123,
          123,
          109,
          109,
          105,
          105,
          105,
        ]) {
          result = _processCoordinatorSample(
            coordinator,
            clock,
            primaryMetric: metric,
          );
        }

        expect(result, isNotNull);
        expect(result!.stateSnapshot.repCount, 1);
        expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
          'low confidence',
        );
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationReasons,
          <String>['excessive rep speed'],
        );
      },
    );

    test(
      'blocks a straight-leg torso hinge when the heel and hip do not rise',
      () {
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: definition.analysisRangeRepContract,
          rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
        );

        RangeRepCoordinatorFrameResult? result;
        for (final metric in <double>[
          105,
          105,
          146,
          146,
          138,
          123,
          113,
          105,
          105,
        ]) {
          result = _processCoordinatorSample(
            coordinator,
            clock,
            primaryMetric: metric,
            landmarks: _calfRaiseElevationLandmarks(isRaised: false),
          );
        }

        expect(result, isNotNull);
        expect(result!.stateSnapshot.repCount, 0);
        expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
          isNull,
        );
      },
    );

    test(
      'blocks recorded-style torso hinge even when the heel landmark drifts upward',
      () {
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: definition.analysisRangeRepContract,
          rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
        );

        RangeRepCoordinatorFrameResult? result;
        for (final metric in <double>[
          114,
          114,
          131,
          159,
          159,
          127,
          120,
          111,
          111,
        ]) {
          result = _processCoordinatorSample(
            coordinator,
            clock,
            primaryMetric: metric,
            landmarks: _calfRaiseTorsoHingeLandmarks(
              isHinged: metric > config.thresholdActive,
            ),
          );
        }

        expect(result, isNotNull);
        expect(result!.stateSnapshot.repCount, 0);
        expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
          isNull,
        );
      },
    );

    test(
      'rejects a bend-driven completed lifecycle when form stays broken',
      () {
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: definition.analysisRangeRepContract,
          rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
        );

        RangeRepCoordinatorFrameResult? result;
        for (final sample in <(double, double)>[
          (105, 175),
          (105, 175),
          (146, 130),
          (146, 130),
          (113, 130),
          (113, 130),
          (105, 175),
          (105, 175),
          (105, 175),
        ]) {
          result = _processCoordinatorSample(
            coordinator,
            clock,
            primaryMetric: sample.$1,
            formMetric: sample.$2,
          );
        }

        expect(result, isNotNull);
        expect(result!.stateSnapshot.repCount, 0);
        expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
          'invalid',
        );
        expect(
          result.stateSnapshot.calibrationMetrics.lastRangeRepValidationReasons,
          contains('persistent form break'),
        );
      },
    );

    test('rejects a 123-degree spike when ROM stays below 10 degrees', () {
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
      );

      RangeRepCoordinatorFrameResult? result;
      for (final metric in <double>[
        115,
        115,
        123,
        123,
        109,
        109,
        115,
        115,
        115,
      ]) {
        result = _processCoordinatorSample(
          coordinator,
          clock,
          primaryMetric: metric,
        );
      }

      expect(result, isNotNull);
      expect(result!.stateSnapshot.repCount, 0);
      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
        'invalid',
      );
      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepValidationReasons,
        contains('insufficient rom'),
      );
    });

    test('keeps observed standing jitter at zero reps through coordinator', () {
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
      );

      RangeRepCoordinatorFrameResult? result;
      for (final metric in <double>[
        115,
        110,
        110,
        103,
        108,
        112,
        109,
        107,
        108,
        107,
        112,
        118,
      ]) {
        result = _processCoordinatorSample(
          coordinator,
          clock,
          primaryMetric: metric,
        );
      }

      expect(result, isNotNull);
      expect(result!.stateSnapshot.repCount, 0);
      expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
    });
  });
}

RangeRepEngineFrameResult _sample(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  final result = engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 140));
  return result;
}

RangeRepCoordinatorFrameResult _processCoordinatorSample(
  DefaultRangeRepCoordinator coordinator,
  TestFakeClock clock, {
  required double primaryMetric,
  double formMetric = 175.0,
  List<PoseLandmark>? landmarks,
}) {
  final leftMetrics = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryMetric,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1.0,
  );
  final result = coordinator.processFrame(
    metrics: ExerciseMetrics(
      primaryAngle: primaryMetric,
      formMetric: formMetric,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      hasPose: true,
      landmarks:
          landmarks ??
          _calfRaiseElevationLandmarks(
            // Movement evidence must be present throughout the active
            // range, not only after crossing the strict peak boundary.
            isRaised: primaryMetric > 121.0,
          ),
      leftRangeRepMetrics: leftMetrics,
      rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
        RangeRepSide.right,
      ),
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
  );
  clock.advance(const Duration(milliseconds: 140));
  return result;
}

List<PoseLandmark> _calfRaiseElevationLandmarks({required bool isRaised}) {
  final verticalOffset = isRaised ? 4.0 : 0.0;
  return <PoseLandmark>[
    buildLandmark(PoseLandmarkType.leftShoulder, 0, 15 - verticalOffset),
    buildLandmark(PoseLandmarkType.leftHip, 0, 40 - verticalOffset),
    buildLandmark(PoseLandmarkType.leftKnee, 0, 65 - verticalOffset),
    buildLandmark(PoseLandmarkType.leftAnkle, 0, 90 - verticalOffset),
    buildLandmark(PoseLandmarkType.leftHeel, 0, 95 - verticalOffset),
    buildLandmark(PoseLandmarkType.leftFootIndex, 10, 100),
  ];
}

List<PoseLandmark> _calfRaiseTorsoHingeLandmarks({required bool isHinged}) {
  if (!isHinged) {
    return _calfRaiseElevationLandmarks(isRaised: false);
  }

  // Reproduces the device failure mode: hip, ankle, and even the inferred heel
  // drift upward while the shoulder-to-hip torso segment folds sharply. A
  // heel-only check would accept this pose-model artefact.
  return <PoseLandmark>[
    buildLandmark(PoseLandmarkType.leftShoulder, -28, 24),
    buildLandmark(PoseLandmarkType.leftHip, -8, 36),
    buildLandmark(PoseLandmarkType.leftKnee, 2, 65),
    buildLandmark(PoseLandmarkType.leftAnkle, 0, 86),
    buildLandmark(PoseLandmarkType.leftHeel, 0, 91),
    buildLandmark(PoseLandmarkType.leftFootIndex, 10, 100),
  ];
}

Pose _calfRaisePose({required double primaryAngle, required double kneeAngle}) {
  final footDirection = (-90.0 + primaryAngle) * math.pi / 180.0;
  final hipDirection = (-90.0 - (180.0 - kneeAngle)) * math.pi / 180.0;
  const ankle = math.Point<double>(0, 0);
  const knee = math.Point<double>(0, -1);
  final footIndex = math.Point<double>(
    math.cos(footDirection),
    math.sin(footDirection),
  );
  final hip = math.Point<double>(
    knee.x + math.cos(hipDirection),
    knee.y + math.sin(hipDirection),
  );

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        hip.x,
        hip.y - 1.0,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        hip.x,
        hip.y,
      ),
      PoseLandmarkType.leftKnee: buildLandmark(
        PoseLandmarkType.leftKnee,
        knee.x,
        knee.y,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        ankle.x,
        ankle.y,
      ),
      PoseLandmarkType.leftHeel: buildLandmark(
        PoseLandmarkType.leftHeel,
        -0.2,
        0.1,
      ),
      PoseLandmarkType.leftFootIndex: buildLandmark(
        PoseLandmarkType.leftFootIndex,
        footIndex.x,
        footIndex.y,
      ),
    },
  );
}
