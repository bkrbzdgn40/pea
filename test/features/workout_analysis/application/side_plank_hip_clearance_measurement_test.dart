import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/side_plank_hip_clearance_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  const measurement = SidePlankHipClearanceMeasurement();

  test('reports near-zero clearance when the hip stays on the floor line', () {
    final value = measurement.measure(
      _pose(hipY: 2),
      side: HoldSide.left,
      useWristSupport: false,
    );

    expect(value, closeTo(0, 0.001));
  });

  test('reports normalized clearance when the hip is lifted', () {
    final value = measurement.measure(
      _pose(hipY: 0),
      side: HoldSide.left,
      useWristSupport: false,
    );

    expect(value, closeTo(0.2, 0.001));
  });

  test('uses the wrist contact line for straight-arm support', () {
    final value = measurement.measure(
      _pose(hipY: 0, wristY: 3, ankleY: 3),
      side: HoldSide.left,
      useWristSupport: true,
    );

    expect(value, closeTo(0.3, 0.001));
  });
}

Pose _pose({required double hipY, double wristY = 3, double ankleY = 2}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        0,
      ),
      PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 0, 2),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        0,
        wristY,
      ),
      PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 5, hipY),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        10,
        ankleY,
      ),
    },
  );
}

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);
}
