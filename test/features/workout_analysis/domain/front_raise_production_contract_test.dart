import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definition = catalog.definitionFor(ExerciseType.frontRaise);

  group('Front Raise production contract', () {
    late TestFakeClock clock;
    late ExerciseConfig config;
    late RangeRepAnalysisEngine engine;
    late DefaultRangeRepCoordinator coordinator;

    setUp(() {
      clock = TestFakeClock();
      config = loadExerciseConfig(definition.analysisConfigAssetPath);
      engine = factory.createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      );
      coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
      );
    });

    test('retains the device-observed neutral angle for ROM validation', () {
      expect(config.thresholdNeutral, 15.0);
      expect(config.thresholdActive, 35.0);
      expect(config.thresholdPeak, 75.0);
      expect(
        definition.analysisRangeRepContract.primaryMetricSmoothingWindow,
        5,
      );
      expect(
        definition.analysisRangeRepContract.neutralBaselineWindow,
        const Duration(milliseconds: 1500),
      );
      expect(
        definition.analysisRangeRepContract.neutralBaselineThresholdMargin,
        0.0,
      );
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        45.0,
      );

      _holdStableSample(coordinator, clock, primaryMetric: 3.0);
      _holdStableSample(coordinator, clock, primaryMetric: 52.0);
      _holdStableSample(coordinator, clock, primaryMetric: 81.0);
      _holdStableSample(coordinator, clock, primaryMetric: 61.0);
      final completed = _holdStableSample(
        coordinator,
        clock,
        primaryMetric: 2.0,
      );

      expect(completed.stateSnapshot.repCount, 1);
      expect(
        completed
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepSummaryPrimaryRom,
        closeTo(78.0, 0.001),
      );
      expect(
        completed.stateSnapshot.calibrationMetrics.lastRangeRepValidationStatus,
        'valid',
      );
      expect(
        completed
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationReasons,
        isEmpty,
      );
    });

    test('keeps consecutive device-like raises anchored below 15 degrees', () {
      const samples =
          <({double neutral, double active, double peak, double returning})>[
            (neutral: 3, active: 52, peak: 81, returning: 61),
            (neutral: 2, active: 51, peak: 92, returning: 51),
            (neutral: 1, active: 53, peak: 95, returning: 53),
            (neutral: 2, active: 61, peak: 98, returning: 60),
            (neutral: 4, active: 49, peak: 92, returning: 39),
            (neutral: 4, active: 61, peak: 81, returning: 37),
            (neutral: 1, active: 64, peak: 90, returning: 72),
          ];

      for (var index = 0; index < samples.length; index++) {
        final sample = samples[index];
        _holdStableSample(coordinator, clock, primaryMetric: sample.neutral);
        _holdStableSample(coordinator, clock, primaryMetric: sample.active);
        _holdStableSample(coordinator, clock, primaryMetric: sample.peak);
        _holdStableSample(coordinator, clock, primaryMetric: sample.returning);
        final completed = _holdStableSample(
          coordinator,
          clock,
          primaryMetric: sample.neutral,
        );

        expect(
          completed.stateSnapshot.repCount,
          index + 1,
          reason: 'sample=$sample',
        );
        expect(
          completed
              .stateSnapshot
              .calibrationMetrics
              .lastRangeRepSummaryPrimaryRom,
          greaterThanOrEqualTo(45.0),
          reason: 'sample=$sample',
        );
        expect(
          completed
              .stateSnapshot
              .calibrationMetrics
              .lastRangeRepValidationReasons,
          isNot(contains('insufficient rom')),
          reason: 'sample=$sample',
        );
      }
    });
  });
}

RangeRepCoordinatorFrameResult _holdStableSample(
  DefaultRangeRepCoordinator coordinator,
  TestFakeClock clock, {
  required double primaryMetric,
}) {
  // Front Raise retains the production five-frame moving average. Feed a
  // stable six-frame plateau so the filtered metric reaches the requested
  // device angle and still has two frames to satisfy transition confirmation.
  late RangeRepCoordinatorFrameResult result;
  for (var frame = 0; frame < 6; frame++) {
    result = _processSample(coordinator, clock, primaryMetric: primaryMetric);
    clock.advance(const Duration(milliseconds: 120));
  }
  return result;
}

RangeRepCoordinatorFrameResult _processSample(
  DefaultRangeRepCoordinator coordinator,
  TestFakeClock clock, {
  required double primaryMetric,
}) {
  const formMetric = 175.0;
  final leftMetrics = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryMetric,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1.0,
  );

  return coordinator.processFrame(
    metrics: ExerciseMetrics(
      primaryAngle: primaryMetric,
      formMetric: formMetric,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      hasPose: true,
      landmarks: const <PoseLandmark>[],
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
}
