import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/setup_camera_view_orientation.dart';

/// Converts ML Kit torso landmarks into aspect-ratio-safe orientation geometry.
class SetupCameraViewPoseAdapter {
  const SetupCameraViewPoseAdapter();

  SetupCameraViewPose fromPose({
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

  SetupCameraViewPose fromLandmarks({
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

  SetupCameraViewPose fromLandmarksByType({
    required Map<PoseLandmarkType, PoseLandmark> landmarksByType,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    _validateImageDimension(imageWidth, 'imageWidth');
    _validateImageDimension(imageHeight, 'imageHeight');
    final scale = math.max(imageWidth, imageHeight);

    SetupCameraViewPoint? point(PoseLandmarkType type) {
      final landmark = landmarksByType[type];
      if (landmark == null) {
        return null;
      }

      final imageX = mirrorHorizontally ? imageWidth - landmark.x : landmark.x;
      return SetupCameraViewPoint(
        x: imageX / scale,
        y: landmark.y / scale,
        z: landmark.z / scale,
        likelihood: landmark.likelihood,
      );
    }

    return SetupCameraViewPose(
      leftShoulder: point(PoseLandmarkType.leftShoulder),
      rightShoulder: point(PoseLandmarkType.rightShoulder),
      leftHip: point(PoseLandmarkType.leftHip),
      rightHip: point(PoseLandmarkType.rightHip),
    );
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
