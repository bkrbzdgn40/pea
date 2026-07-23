import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/hold_side.dart';
import 'pose_landmark_mirror.dart';

/// Measures how strongly the selected elbow sits below its shoulder in the
/// image plane, normalized by shoulder-to-elbow segment length.
///
/// Positive values mean the elbow is below the shoulder because image y grows
/// downward. +1 is perfectly vertical support, 0 is horizontal, and negative
/// values place the elbow above the shoulder. The measurement is scale
/// invariant and intentionally carries no policy threshold.
class SidePlankSupportStackingMeasurement {
  const SidePlankSupportStackingMeasurement();

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
    final elbowType = resolveHoldLandmarkForSide(
      configuredLandmark: PoseLandmarkType.leftElbow,
      referenceSide: referenceSide,
      targetSide: side,
    );
    final shoulder = pose.landmarks[shoulderType];
    final elbow = pose.landmarks[elbowType];
    if (shoulder == null || elbow == null) {
      return null;
    }

    final dx = elbow.x - shoulder.x;
    final dy = elbow.y - shoulder.y;
    final length = math.sqrt((dx * dx) + (dy * dy));
    if (length == 0) {
      return null;
    }

    return dy / length;
  }
}
