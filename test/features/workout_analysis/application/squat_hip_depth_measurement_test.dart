import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/squat_hip_depth_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = SquatHipDepthMeasurement();

  group('SquatHipDepthMeasurement', () {
    test('normalizes selected-side hip height by lower-leg length', () {
      final pose = _poseWithHipDepth(
        side: RangeRepSide.left,
        hipY: 0,
        kneeY: 2,
        ankleY: 6,
      );

      expect(
        measurement.measure(pose, side: RangeRepSide.left),
        closeTo(0.5, 0.001),
      );
    });

    test('preserves above, level, and below knee image-height semantics', () {
      expect(
        measurement.measure(
          _poseWithHipDepth(
            side: RangeRepSide.left,
            hipY: 0,
            kneeY: 2,
            ankleY: 6,
          ),
          side: RangeRepSide.left,
        ),
        closeTo(0.5, 0.001),
      );
      expect(
        measurement.measure(
          _poseWithHipDepth(
            side: RangeRepSide.left,
            hipY: 2,
            kneeY: 2,
            ankleY: 6,
          ),
          side: RangeRepSide.left,
        ),
        closeTo(0.0, 0.001),
      );
      expect(
        measurement.measure(
          _poseWithHipDepth(
            side: RangeRepSide.left,
            hipY: 4,
            kneeY: 2,
            ankleY: 6,
          ),
          side: RangeRepSide.left,
        ),
        closeTo(-0.5, 0.001),
      );
    });

    test('mirrors the measurement to the selected right side', () {
      final pose = _poseWithHipDepth(
        side: RangeRepSide.right,
        hipY: 0,
        kneeY: 3,
        ankleY: 9,
      );

      expect(
        measurement.measure(pose, side: RangeRepSide.right),
        closeTo(0.5, 0.001),
      );
      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measure(
        _poseWithHipDepth(
          side: RangeRepSide.left,
          hipY: 0,
          kneeY: 2,
          ankleY: 6,
        ),
        side: RangeRepSide.left,
      );
      final scaled = measurement.measure(
        _poseWithHipDepth(
          side: RangeRepSide.left,
          hipY: 0,
          kneeY: 8,
          ankleY: 24,
        ),
        side: RangeRepSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null when a required landmark is missing', () {
      final pose = Pose(
        landmarks: <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftHip: buildLandmark(
            PoseLandmarkType.leftHip,
            0,
            0,
            likelihood: 0.95,
          ),
          PoseLandmarkType.leftKnee: buildLandmark(
            PoseLandmarkType.leftKnee,
            0,
            2,
            likelihood: 0.95,
          ),
        },
      );

      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });

    test('returns null for a zero-length knee-to-ankle segment', () {
      final pose = _poseWithHipDepth(
        side: RangeRepSide.left,
        hipY: 0,
        kneeY: 2,
        ankleY: 2,
      );

      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });
  });

  test('production squat coordinator exposes the diagnostic signal', () {
    final config = buildSquatConfig();
    final engine = const AnalysisEngineFactory().createRangeRep(
      config: config,
      rangeRepContract: RangeRepContracts.squat,
      now: DateTime.now,
    );
    final coordinator = DefaultRangeRepCoordinator(
      engine: engine,
      config: config,
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: const RangeRepValidationConfig(
        minAcceptableRomAngle: 110,
        minDescentMillis: 300,
        minAscentMillis: 250,
        allowLowConfidenceOnCoverageLoss: true,
      ),
    );
    final metrics = const ExerciseMetricsExtractor().extract(
      _productionSquatPose(),
      config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.squat,
    );

    coordinator.processFrame(
      metrics: metrics,
      now: DateTime.utc(2030, 1, 1),
      isAcceptedPoseFrame: true,
      didBecomeStableTracking: false,
      qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
      preferredRangeRepSide: RangeRepSide.left,
    );

    expect(coordinator.currentSquatHipDepthMetric, closeTo(0.5, 0.001));
    expect(coordinator.techniqueObservations, isEmpty);

    coordinator.handleLifecycleInterruption(reason: 'test');

    expect(coordinator.currentSquatHipDepthMetric, isNull);
  });
}

Pose _poseWithHipDepth({
  required RangeRepSide side,
  required double hipY,
  required double kneeY,
  required double ankleY,
}) {
  final isLeft = side == RangeRepSide.left;
  final hipType = isLeft
      ? PoseLandmarkType.leftHip
      : PoseLandmarkType.rightHip;
  final kneeType = isLeft
      ? PoseLandmarkType.leftKnee
      : PoseLandmarkType.rightKnee;
  final ankleType = isLeft
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      hipType: buildLandmark(hipType, 0, hipY, likelihood: 0.95),
      kneeType: buildLandmark(kneeType, 0, kneeY, likelihood: 0.95),
      ankleType: buildLandmark(ankleType, 0, ankleY, likelihood: 0.95),
    },
  );
}

Pose _productionSquatPose() {
  final pose = buildSquatPose(angle: 170);
  final landmarks = Map<PoseLandmarkType, PoseLandmark>.from(pose.landmarks);
  landmarks[PoseLandmarkType.leftHip] = buildLandmark(
    PoseLandmarkType.leftHip,
    0,
    0,
    likelihood: 0.95,
  );
  landmarks[PoseLandmarkType.leftKnee] = buildLandmark(
    PoseLandmarkType.leftKnee,
    0,
    2,
    likelihood: 0.95,
  );
  landmarks[PoseLandmarkType.leftAnkle] = buildLandmark(
    PoseLandmarkType.leftAnkle,
    0,
    6,
    likelihood: 0.95,
  );
  return Pose(landmarks: landmarks);
}
