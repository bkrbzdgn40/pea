import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/squat_torso_inclination_measurement.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = SquatTorsoInclinationMeasurement();

  test('measures selected-side shoulder-to-hip inclination from vertical', () {
    final pose = _poseWithTorsoInclination(30.0, side: RangeRepSide.left);

    expect(
      measurement.measure(pose, side: RangeRepSide.left),
      closeTo(30.0, 0.001),
    );
  });

  test('mirrors the torso measurement to the selected right side', () {
    final pose = _poseWithTorsoInclination(42.0, side: RangeRepSide.right);

    expect(
      measurement.measure(pose, side: RangeRepSide.right),
      closeTo(42.0, 0.001),
    );
    expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
  });

  test('keeps vertical and horizontal image-plane endpoints explicit', () {
    expect(
      measurement.measure(
        _poseWithTorsoInclination(0.0, side: RangeRepSide.left),
        side: RangeRepSide.left,
      ),
      closeTo(0.0, 0.001),
    );
    expect(
      measurement.measure(
        _poseWithTorsoInclination(90.0, side: RangeRepSide.left),
        side: RangeRepSide.left,
      ),
      closeTo(90.0, 0.001),
    );
  });

  test('returns null when a required torso landmark is missing', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftHip: buildLandmark(
          PoseLandmarkType.leftHip,
          0,
          0,
          likelihood: 0.95,
        ),
      },
    );

    expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
  });

  test('returns null for a zero-length shoulder-to-hip segment', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftShoulder: buildLandmark(
          PoseLandmarkType.leftShoulder,
          2,
          3,
          likelihood: 0.95,
        ),
        PoseLandmarkType.leftHip: buildLandmark(
          PoseLandmarkType.leftHip,
          2,
          3,
          likelihood: 0.95,
        ),
      },
    );

    expect(measurement.measure(pose, side: RangeRepSide.left), isNull);
  });
}

Pose _poseWithTorsoInclination(
  double inclinationDegrees, {
  required RangeRepSide side,
}) {
  final radians = inclinationDegrees * math.pi / 180.0;
  final shoulderType = side == RangeRepSide.left
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final hipType = side == RangeRepSide.left
      ? PoseLandmarkType.leftHip
      : PoseLandmarkType.rightHip;

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      shoulderType: buildLandmark(
        shoulderType,
        math.sin(radians),
        -math.cos(radians),
        likelihood: 0.95,
      ),
      hipType: buildLandmark(hipType, 0, 0, likelihood: 0.95),
    },
  );
}
