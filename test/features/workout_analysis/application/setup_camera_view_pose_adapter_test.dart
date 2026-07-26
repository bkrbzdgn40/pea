import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/setup_camera_view_pose_adapter.dart';

void main() {
  const adapter = SetupCameraViewPoseAdapter();

  test('normalizes torso coordinates against the longest image side', () {
    final pose = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[
        _landmark(PoseLandmarkType.leftShoulder, 20, 40, z: -10),
        _landmark(PoseLandmarkType.rightShoulder, 80, 40, z: 10),
        _landmark(PoseLandmarkType.leftHip, 30, 120, z: -8),
        _landmark(PoseLandmarkType.rightHip, 70, 120, z: 8),
      ],
      imageWidth: 100,
      imageHeight: 200,
    );

    expect(pose.leftShoulder!.x, closeTo(0.1, 1e-9));
    expect(pose.leftShoulder!.y, closeTo(0.2, 1e-9));
    expect(pose.leftShoulder!.z, closeTo(-0.05, 1e-9));
    expect(pose.rightHip!.x, closeTo(0.35, 1e-9));
    expect(pose.rightHip!.y, closeTo(0.6, 1e-9));
  });

  test('mirrors x coordinates without changing pair distances', () {
    final normal = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[
        _landmark(PoseLandmarkType.leftShoulder, 20, 40),
        _landmark(PoseLandmarkType.rightShoulder, 80, 40),
      ],
      imageWidth: 100,
      imageHeight: 200,
    );
    final mirrored = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[
        _landmark(PoseLandmarkType.leftShoulder, 20, 40),
        _landmark(PoseLandmarkType.rightShoulder, 80, 40),
      ],
      imageWidth: 100,
      imageHeight: 200,
      mirrorHorizontally: true,
    );

    expect(mirrored.leftShoulder!.x, closeTo(0.4, 1e-9));
    expect(mirrored.rightShoulder!.x, closeTo(0.1, 1e-9));
    expect(
      (mirrored.leftShoulder!.x - mirrored.rightShoulder!.x).abs(),
      closeTo((normal.leftShoulder!.x - normal.rightShoulder!.x).abs(), 1e-9),
    );
  });

  test('ignores non-torso landmarks and preserves likelihood', () {
    final pose = adapter.fromLandmarks(
      landmarks: <PoseLandmark>[
        _landmark(PoseLandmarkType.leftShoulder, 20, 40, likelihood: 0.42),
        _landmark(PoseLandmarkType.leftWrist, 10, 90),
      ],
      imageWidth: 100,
      imageHeight: 200,
    );

    expect(pose.leftShoulder!.likelihood, 0.42);
    expect(pose.rightShoulder, isNull);
    expect(pose.leftHip, isNull);
    expect(pose.rightHip, isNull);
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
        imageHeight: double.infinity,
      ),
      throwsArgumentError,
    );
  });
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double z = 0,
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: z, likelihood: likelihood);
}
