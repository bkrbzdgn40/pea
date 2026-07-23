import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/side_plank_support_stacking_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  const measurement = SidePlankSupportStackingMeasurement();

  test('returns +1 when the selected elbow is directly below the shoulder', () {
    final value = measurement.measure(
      _pose(shoulderX: 0, shoulderY: 0, elbowX: 0, elbowY: 2),
      side: HoldSide.left,
    );

    expect(value, closeTo(1, 0.001));
  });

  test('returns negative support evidence when elbow is above shoulder', () {
    final value = measurement.measure(
      _pose(shoulderX: 0, shoulderY: 2, elbowX: 0, elbowY: 0),
      side: HoldSide.left,
    );

    expect(value, closeTo(-1, 0.001));
  });

  test('returns zero for a horizontal shoulder-elbow segment', () {
    final value = measurement.measure(
      _pose(shoulderX: 0, shoulderY: 0, elbowX: 2, elbowY: 0),
      side: HoldSide.left,
    );

    expect(value, closeTo(0, 0.001));
  });

  test('mirrors the measurement to the selected right side', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.rightShoulder: PoseLandmark(
          type: PoseLandmarkType.rightShoulder,
          x: 2,
          y: 0,
          z: 0,
          likelihood: 0.99,
        ),
        PoseLandmarkType.rightElbow: PoseLandmark(
          type: PoseLandmarkType.rightElbow,
          x: 2,
          y: 3,
          z: 0,
          likelihood: 0.99,
        ),
      },
    );

    expect(measurement.measure(pose, side: HoldSide.right), closeTo(1, 0.001));
    expect(measurement.measure(pose, side: HoldSide.left), isNull);
  });

  test('returns null for a degenerate shoulder-elbow segment', () {
    final value = measurement.measure(
      _pose(shoulderX: 1, shoulderY: 1, elbowX: 1, elbowY: 1),
      side: HoldSide.left,
    );

    expect(value, isNull);
  });
}

Pose _pose({
  required double shoulderX,
  required double shoulderY,
  required double elbowX,
  required double elbowY,
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: PoseLandmark(
        type: PoseLandmarkType.leftShoulder,
        x: shoulderX,
        y: shoulderY,
        z: 0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftElbow: PoseLandmark(
        type: PoseLandmarkType.leftElbow,
        x: elbowX,
        y: elbowY,
        z: 0,
        likelihood: 0.99,
      ),
    },
  );
}
