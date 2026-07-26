import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/setup_framing_pose_adapter.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/setup_framing_geometry_evaluator.dart';

void main() {
  const adapter = SetupFramingPoseAdapter();

  test('normalizes and groups ML Kit landmarks by setup body region', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.nose: _landmark(
          PoseLandmarkType.nose,
          x: 50,
          y: 20,
          likelihood: 0.9,
        ),
        PoseLandmarkType.leftShoulder: _landmark(
          PoseLandmarkType.leftShoulder,
          x: 30,
          y: 40,
          likelihood: 0.8,
        ),
        PoseLandmarkType.rightShoulder: _landmark(
          PoseLandmarkType.rightShoulder,
          x: 70,
          y: 40,
          likelihood: 0.85,
        ),
        PoseLandmarkType.leftFootIndex: _landmark(
          PoseLandmarkType.leftFootIndex,
          x: 35,
          y: 180,
          likelihood: 0.75,
        ),
      },
    );

    final normalized = adapter.fromPose(
      pose: pose,
      imageWidth: 100,
      imageHeight: 200,
    );

    expect(normalized.landmarksFor(SetupBodyRegion.head), hasLength(1));
    expect(normalized.landmarksFor(SetupBodyRegion.shoulders), hasLength(2));
    expect(normalized.landmarksFor(SetupBodyRegion.feet), hasLength(1));
    expect(
      normalized.landmarksFor(SetupBodyRegion.head).single.x,
      closeTo(0.5, 0.0001),
    );
    expect(
      normalized.landmarksFor(SetupBodyRegion.feet).single.y,
      closeTo(0.9, 0.0001),
    );
  });

  test('mirrors normalized x coordinates without changing y', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftHip: _landmark(
          PoseLandmarkType.leftHip,
          x: 20,
          y: 80,
        ),
      },
    );

    final normalized = adapter.fromPose(
      pose: pose,
      imageWidth: 100,
      imageHeight: 200,
      mirrorHorizontally: true,
    );
    final hip = normalized.landmarksFor(SetupBodyRegion.hips).single;

    expect(hip.x, closeTo(0.8, 0.0001));
    expect(hip.y, closeTo(0.4, 0.0001));
  });

  test('keeps coordinates outside the frame for clipping diagnostics', () {
    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftWrist: _landmark(
          PoseLandmarkType.leftWrist,
          x: -5,
          y: 210,
        ),
      },
    );

    final normalized = adapter.fromPose(
      pose: pose,
      imageWidth: 100,
      imageHeight: 200,
    );
    final wrist = normalized.landmarksFor(SetupBodyRegion.wrists).single;

    expect(wrist.x, closeTo(-0.05, 0.0001));
    expect(wrist.y, closeTo(1.05, 0.0001));
  });

  test('rejects invalid image dimensions', () {
    final pose = Pose(landmarks: const <PoseLandmarkType, PoseLandmark>{});

    expect(
      () => adapter.fromPose(pose: pose, imageWidth: 0, imageHeight: 100),
      throwsArgumentError,
    );
    expect(
      () => adapter.fromPose(
        pose: pose,
        imageWidth: 100,
        imageHeight: double.nan,
      ),
      throwsArgumentError,
    );
  });

  test('all supported exercise contracts resolve a framing profile', () {
    const catalog = ExerciseCatalog();
    const resolver = SetupFramingThresholdResolver();

    for (final definition in catalog.definitions) {
      final thresholds = resolver.resolve(definition.analysisSetupContract);
      expect(
        thresholds.minimumBodyScaleRatio,
        lessThan(thresholds.maximumBodyScaleRatio),
        reason: definition.type.name,
      );
      expect(
        definition.analysisSetupContract.bodyCoverage.requiredRegions,
        isNotEmpty,
        reason: definition.type.name,
      );
    }
  });
}

PoseLandmark _landmark(
  PoseLandmarkType type, {
  required double x,
  required double y,
  double likelihood = 1,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}
