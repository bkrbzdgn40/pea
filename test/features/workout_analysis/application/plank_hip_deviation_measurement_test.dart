import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/plank_hip_deviation_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = PlankHipDeviationMeasurement();
  const extractor = ExerciseMetricsExtractor();

  group('PlankHipDeviationMeasurement', () {
    test('returns zero when hip lies on the shoulder-ankle line', () {
      final value = measurement.measure(
        _pose(
          _landmarks(
            side: HoldSide.left,
            shoulderX: -1,
            shoulderY: 0,
            hipX: 0,
            hipY: 0,
            ankleX: 1,
            ankleY: 0,
          ),
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.0, 0.001));
    });

    test('normalizes hip deviation by shoulder-ankle length', () {
      final value = measurement.measure(
        _pose(
          _landmarks(
            side: HoldSide.left,
            shoulderX: -1,
            shoulderY: 0,
            hipX: 0,
            hipY: 0.5,
            ankleX: 1,
            ankleY: 0,
          ),
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.25, 0.001));
    });

    test('mirrors the measurement to the selected right side', () {
      final pose = _pose(
        _landmarks(
          side: HoldSide.right,
          shoulderX: 3,
          shoulderY: 0,
          hipX: 4,
          hipY: 1,
          ankleX: 5,
          ankleY: 0,
        ),
      );

      expect(
        measurement.measure(pose, side: HoldSide.right),
        closeTo(0.5, 0.001),
      );
      expect(measurement.measure(pose, side: HoldSide.left), isNull);
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measure(
        _pose(
          _landmarks(
            side: HoldSide.left,
            shoulderX: -1,
            shoulderY: 0,
            hipX: 0,
            hipY: 1,
            ankleX: 1,
            ankleY: 0,
          ),
        ),
        side: HoldSide.left,
      );
      final scaled = measurement.measure(
        _pose(
          _landmarks(
            side: HoldSide.left,
            shoulderX: -4,
            shoulderY: 0,
            hipX: 0,
            hipY: 4,
            ankleX: 4,
            ankleY: 0,
          ),
        ),
        side: HoldSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null for missing landmarks and a degenerate body line', () {
      final missingAnkle = _pose(<PoseLandmark>[
        buildLandmark(PoseLandmarkType.leftShoulder, -1, 0, likelihood: 0.95),
        buildLandmark(PoseLandmarkType.leftHip, 0, 1, likelihood: 0.95),
      ]);
      final zeroLength = _pose(
        _landmarks(
          side: HoldSide.left,
          shoulderX: 0,
          shoulderY: 0,
          hipX: 0,
          hipY: 1,
          ankleX: 0,
          ankleY: 0,
        ),
      );

      expect(measurement.measure(missingAnkle, side: HoldSide.left), isNull);
      expect(measurement.measure(zeroLength, side: HoldSide.left), isNull);
    });
  });

  test(
    'generic hold transport stays legacy while plank owns hip measurement',
    () {
      final pose = _fullPlankPose(hipY: 0.5);
      final metrics = extractor.extract(
        pose,
        buildPlankConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        metrics.holdSignalValues.signals,
        everyElement(isIn(HoldContracts.plankFamily.requiredSignals)),
      );
      expect(
        measurement.measure(pose, side: HoldSide.left),
        closeTo(0.25, 0.001),
      );
    },
  );
}

Pose _pose(List<PoseLandmark> landmarks) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    },
  );
}

Pose _fullPlankPose({required double hipY}) {
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
        -1,
        1,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftWrist: buildLandmark(
        PoseLandmarkType.leftWrist,
        0,
        1,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        0,
        hipY,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftKnee: buildLandmark(
        PoseLandmarkType.leftKnee,
        0.5,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        1,
        0,
        likelihood: 0.95,
      ),
    },
  );
}

List<PoseLandmark> _landmarks({
  required HoldSide side,
  required double shoulderX,
  required double shoulderY,
  required double hipX,
  required double hipY,
  required double ankleX,
  required double ankleY,
}) {
  final isLeft = side == HoldSide.left;
  final shoulderType = isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final hipType = isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip;
  final ankleType = isLeft
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;

  return <PoseLandmark>[
    buildLandmark(shoulderType, shoulderX, shoulderY, likelihood: 0.95),
    buildLandmark(hipType, hipX, hipY, likelihood: 0.95),
    buildLandmark(ankleType, ankleX, ankleY, likelihood: 0.95),
  ];
}
