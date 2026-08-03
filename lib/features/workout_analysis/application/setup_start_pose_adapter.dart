import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/setup_start_pose.dart';

/// Converts ML Kit landmarks into the presentation-independent start-pose model.
class SetupStartPoseAdapter {
  const SetupStartPoseAdapter();

  static const Map<PoseLandmarkType, SetupStartPoseJoint> _jointByLandmark =
      <PoseLandmarkType, SetupStartPoseJoint>{
        PoseLandmarkType.leftShoulder: SetupStartPoseJoint.leftShoulder,
        PoseLandmarkType.rightShoulder: SetupStartPoseJoint.rightShoulder,
        PoseLandmarkType.leftElbow: SetupStartPoseJoint.leftElbow,
        PoseLandmarkType.rightElbow: SetupStartPoseJoint.rightElbow,
        PoseLandmarkType.leftWrist: SetupStartPoseJoint.leftWrist,
        PoseLandmarkType.rightWrist: SetupStartPoseJoint.rightWrist,
        PoseLandmarkType.leftHip: SetupStartPoseJoint.leftHip,
        PoseLandmarkType.rightHip: SetupStartPoseJoint.rightHip,
        PoseLandmarkType.leftKnee: SetupStartPoseJoint.leftKnee,
        PoseLandmarkType.rightKnee: SetupStartPoseJoint.rightKnee,
        PoseLandmarkType.leftAnkle: SetupStartPoseJoint.leftAnkle,
        PoseLandmarkType.rightAnkle: SetupStartPoseJoint.rightAnkle,
        PoseLandmarkType.leftHeel: SetupStartPoseJoint.leftHeel,
        PoseLandmarkType.rightHeel: SetupStartPoseJoint.rightHeel,
        PoseLandmarkType.leftFootIndex: SetupStartPoseJoint.leftFootIndex,
        PoseLandmarkType.rightFootIndex: SetupStartPoseJoint.rightFootIndex,
      };

  SetupStartPose fromPose({
    required Pose pose,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    return fromLandmarks(
      landmarks: pose.landmarks.values,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
  }

  SetupStartPose fromLandmarks({
    required Iterable<PoseLandmark> landmarks,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    return fromLandmarksByType(
      landmarksByType: <PoseLandmarkType, PoseLandmark>{
        for (final landmark in landmarks) landmark.type: landmark,
      },
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
  }

  SetupStartPose fromLandmarksByType({
    required Map<PoseLandmarkType, PoseLandmark> landmarksByType,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    _validateImageDimension(imageWidth, 'imageWidth');
    _validateImageDimension(imageHeight, 'imageHeight');
    final sharedScale = math.max(imageWidth, imageHeight);
    final points = <SetupStartPoseJoint, SetupStartPosePoint>{};

    for (final landmark in landmarksByType.values) {
      final joint = _jointByLandmark[landmark.type];
      if (joint == null) {
        continue;
      }

      final normalizedX = landmark.x / sharedScale;
      points[joint] = SetupStartPosePoint(
        x: mirrorHorizontally
            ? (imageWidth / sharedScale) - normalizedX
            : normalizedX,
        y: landmark.y / sharedScale,
        z: landmark.z / sharedScale,
        likelihood: landmark.likelihood,
      );
    }

    return SetupStartPose(points: points);
  }

  void _validateImageDimension(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'Image dimensions must be finite and greater than zero.',
      );
    }
  }
}
