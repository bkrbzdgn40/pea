import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';
import 'pose_landmark_mirror.dart';

/// Measures selected-side plank hip deviation from the shoulder-to-ankle line
/// in the 2D image plane, normalized by the shoulder-to-ankle segment length.
///
/// This is a physical, dimensionless measurement only. It deliberately does
/// not assign sag/pike direction, severity, validation, hold-break, scoring, or
/// coaching semantics.
class PlankHipDeviationMeasurement {
  const PlankHipDeviationMeasurement();

  double? measure(
    Pose pose, {
    required HoldSide side,
    HoldSide referenceSide = HoldSide.left,
  }) {
    final shoulderType = resolveHoldLandmarkForSide(
      configuredLandmark: PoseLandmarkType.leftShoulder,
      referenceSide: referenceSide,
      targetSide: side,
    );
    final hipType = resolveHoldLandmarkForSide(
      configuredLandmark: PoseLandmarkType.leftHip,
      referenceSide: referenceSide,
      targetSide: side,
    );
    final ankleType = resolveHoldLandmarkForSide(
      configuredLandmark: PoseLandmarkType.leftAnkle,
      referenceSide: referenceSide,
      targetSide: side,
    );
    final shoulder = pose.landmarks[shoulderType];
    final hip = pose.landmarks[hipType];
    final ankle = pose.landmarks[ankleType];
    if (shoulder == null || hip == null || ankle == null) {
      return null;
    }

    return normalizedPointToLineDeviation(
      point: math.Point<double>(hip.x, hip.y),
      lineStart: math.Point<double>(shoulder.x, shoulder.y),
      lineEnd: math.Point<double>(ankle.x, ankle.y),
    );
  }
}
