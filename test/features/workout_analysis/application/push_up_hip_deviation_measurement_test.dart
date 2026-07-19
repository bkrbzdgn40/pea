import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/push_up_hip_deviation_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = PushUpHipDeviationMeasurement();

  group('PushUpHipDeviationMeasurement', () {
    test('returns zero when the hip lies on the shoulder-ankle line', () {
      final pose = _poseWithPushUpHipDeviation(
        side: RangeRepSide.left,
        shoulder: const _Point(-1, 0),
        hip: const _Point(0, 0),
        ankle: const _Point(1, 0),
      );

      expect(
        measurement.measure(pose, side: RangeRepSide.left),
        closeTo(0.0, 0.001),
      );
    });

    test('returns the same magnitude for equal deviations on either side', () {
      final above = measurement.measure(
        _poseWithPushUpHipDeviation(
          side: RangeRepSide.left,
          shoulder: const _Point(-1, 0),
          hip: const _Point(0, 1),
          ankle: const _Point(1, 0),
        ),
        side: RangeRepSide.left,
      );
      final below = measurement.measure(
        _poseWithPushUpHipDeviation(
          side: RangeRepSide.left,
          shoulder: const _Point(-1, 0),
          hip: const _Point(0, -1),
          ankle: const _Point(1, 0),
        ),
        side: RangeRepSide.left,
      );

      expect(above, closeTo(0.5, 0.001));
      expect(below, closeTo(0.5, 0.001));
    });

    test('mirrors the measurement to the selected right side', () {
      final pose = _poseWithPushUpHipDeviation(
        side: RangeRepSide.right,
        shoulder: const _Point(3, 0),
        hip: const _Point(4, 1),
        ankle: const _Point(5, 0),
      );

      expect(
        measurement.measure(pose, side: RangeRepSide.right),
        closeTo(0.5, 0.001),
      );
      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measure(
        _poseWithPushUpHipDeviation(
          side: RangeRepSide.left,
          shoulder: const _Point(-1, 0),
          hip: const _Point(0, 1),
          ankle: const _Point(1, 0),
        ),
        side: RangeRepSide.left,
      );
      final scaled = measurement.measure(
        _poseWithPushUpHipDeviation(
          side: RangeRepSide.left,
          shoulder: const _Point(-2, 0),
          hip: const _Point(0, 2),
          ankle: const _Point(2, 0),
        ),
        side: RangeRepSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null when a required landmark is missing', () {
      final pose = Pose(
        landmarks: <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftShoulder: buildLandmark(
            PoseLandmarkType.leftShoulder,
            -1,
            0,
            likelihood: 0.95,
          ),
          PoseLandmarkType.leftHip: buildLandmark(
            PoseLandmarkType.leftHip,
            0,
            1,
            likelihood: 0.95,
          ),
        },
      );

      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });

    test('returns null for a zero-length shoulder-to-ankle segment', () {
      final pose = _poseWithPushUpHipDeviation(
        side: RangeRepSide.left,
        shoulder: const _Point(0, 0),
        hip: const _Point(0, 1),
        ankle: const _Point(0, 0),
      );

      expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
    });
  });

  test('production push-up coordinator exposes the diagnostic signal', () {
    final config = loadExerciseConfig('assets/config/exercises/push_up.json');
    final engine = const AnalysisEngineFactory().createRangeRep(
      config: config,
      rangeRepContract: RangeRepContracts.pushUp,
      now: DateTime.now,
    );
    final coordinator = DefaultRangeRepCoordinator(
      engine: engine,
      config: config,
      rangeRepContract: RangeRepContracts.pushUp,
      rangeRepValidationConfig: const RangeRepValidationConfig(
        minAcceptableRomAngle: 110,
        minDescentMillis: 250,
        minAscentMillis: 250,
        allowLowConfidenceOnCoverageLoss: true,
      ),
    );
    final metrics = const ExerciseMetricsExtractor().extract(
      _productionPushUpPose(),
      config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.pushUp,
    );

    coordinator.processFrame(
      metrics: metrics,
      now: DateTime.utc(2030, 1, 1),
      isAcceptedPoseFrame: true,
      didBecomeStableTracking: false,
      qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
      preferredRangeRepSide: RangeRepSide.left,
    );

    expect(coordinator.currentPushUpHipDeviationMetric, closeTo(0.0625, 0.001));
    expect(coordinator.techniqueObservations, isEmpty);

    coordinator.processFrame(
      metrics: metrics,
      now: DateTime.utc(2030, 1, 1, 0, 0, 1),
      isAcceptedPoseFrame: false,
      didBecomeStableTracking: false,
      qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
      preferredRangeRepSide: RangeRepSide.left,
    );

    expect(coordinator.currentPushUpHipDeviationMetric, isNull);

    coordinator.handleLifecycleInterruption(reason: 'test');

    expect(coordinator.currentPushUpHipDeviationMetric, isNull);
  });
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}

Pose _poseWithPushUpHipDeviation({
  required RangeRepSide side,
  required _Point shoulder,
  required _Point hip,
  required _Point ankle,
}) {
  final isLeft = side == RangeRepSide.left;
  final shoulderType = isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final hipType = isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip;
  final ankleType = isLeft
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      shoulderType: buildLandmark(
        shoulderType,
        shoulder.x,
        shoulder.y,
        likelihood: 0.95,
      ),
      hipType: buildLandmark(hipType, hip.x, hip.y, likelihood: 0.95),
      ankleType: buildLandmark(ankleType, ankle.x, ankle.y, likelihood: 0.95),
    },
  );
}

Pose _productionPushUpPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        -1,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftElbow: buildLandmark(
        PoseLandmarkType.leftElbow,
        0,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftWrist: buildLandmark(
        PoseLandmarkType.leftWrist,
        1,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        0,
        0.25,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        3,
        0,
        likelihood: 0.95,
      ),
    },
  );
}
