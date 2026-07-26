import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/setup_start_pose_adapter.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_start_pose.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const adapter = SetupStartPoseAdapter();

  test('maps supported ML Kit joints with a shared image scale', () {
    final pose = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[
        buildLandmark(PoseLandmarkType.leftShoulder, 40, 60),
        buildLandmark(PoseLandmarkType.leftHip, 50, 120),
        buildLandmark(PoseLandmarkType.nose, 50, 20),
      ],
      imageWidth: 100,
      imageHeight: 200,
    );

    expect(pose.points, hasLength(2));
    expect(
      pose.pointFor(SetupStartPoseJoint.leftShoulder)?.x,
      closeTo(0.2, 0.0001),
    );
    expect(
      pose.pointFor(SetupStartPoseJoint.leftShoulder)?.y,
      closeTo(0.3, 0.0001),
    );
    expect(pose.pointFor(SetupStartPoseJoint.leftHip)?.y, closeTo(0.6, 0.0001));
  });

  test('mirrors x without changing y, z, or confidence', () {
    final landmark = PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: 20,
      y: 40,
      z: 10,
      likelihood: 0.8,
    );
    final normal = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[landmark],
      imageWidth: 100,
      imageHeight: 200,
    );
    final mirrored = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[landmark],
      imageWidth: 100,
      imageHeight: 200,
      mirrorHorizontally: true,
    );

    final normalPoint = normal.pointFor(SetupStartPoseJoint.leftShoulder)!;
    final mirroredPoint = mirrored.pointFor(SetupStartPoseJoint.leftShoulder)!;
    expect(normalPoint.x, closeTo(0.1, 0.0001));
    expect(mirroredPoint.x, closeTo(0.4, 0.0001));
    expect(mirroredPoint.y, normalPoint.y);
    expect(mirroredPoint.z, normalPoint.z);
    expect(mirroredPoint.likelihood, normalPoint.likelihood);
  });

  test('rejects invalid image dimensions', () {
    expect(
      () => adapter.fromLandmarks(
        landmarks: const <PoseLandmark>[],
        imageWidth: 0,
        imageHeight: 200,
      ),
      throwsArgumentError,
    );
    expect(
      () => adapter.fromLandmarks(
        landmarks: const <PoseLandmark>[],
        imageWidth: 100,
        imageHeight: double.nan,
      ),
      throwsArgumentError,
    );
  });
}
