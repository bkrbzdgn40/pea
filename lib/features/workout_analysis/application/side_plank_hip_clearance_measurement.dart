import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';
import 'pose_landmark_mirror.dart';

/// Measures selected-side hip clearance from the support-contact-to-ankle line.
///
/// In a side plank, the support contact (elbow for forearm support or wrist for
/// straight-arm support) and the ankle approximate the floor support line. A
/// collapsed hip stays close to that line, while a lifted hip has a meaningful
/// normalized point-to-line distance.
///
/// This is a scale-independent image-plane measurement whose sign is normalized
/// to the shoulder side of the support line. Positive values indicate that the
/// hip clears the floor line in the expected direction. Posture and hold-start
/// semantics remain owned by the side-plank posture policy.
class SidePlankHipClearanceMeasurement {
  const SidePlankHipClearanceMeasurement();

  double? measure(
    Pose pose, {
    required HoldSide side,
    required bool useWristSupport,
    HoldSide referenceSide = HoldSide.left,
  }) {
    final supportType = resolveHoldLandmarkForSide(
      configuredLandmark: useWristSupport
          ? PoseLandmarkType.leftWrist
          : PoseLandmarkType.leftElbow,
      referenceSide: referenceSide,
      targetSide: side,
    );
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
    final support = pose.landmarks[supportType];
    final shoulder = pose.landmarks[shoulderType];
    final hip = pose.landmarks[hipType];
    final ankle = pose.landmarks[ankleType];
    if (support == null || shoulder == null || hip == null || ankle == null) {
      return null;
    }

    final lineStart = math.Point<double>(support.x, support.y);
    final lineEnd = math.Point<double>(ankle.x, ankle.y);
    final shoulderDeviation = signedDeviation(
      point: math.Point<double>(shoulder.x, shoulder.y),
      lineStart: lineStart,
      lineEnd: lineEnd,
    );
    final hipDeviation = signedDeviation(
      point: math.Point<double>(hip.x, hip.y),
      lineStart: lineStart,
      lineEnd: lineEnd,
    );
    if (shoulderDeviation == null ||
        hipDeviation == null ||
        shoulderDeviation == 0.0) {
      return null;
    }

    return shoulderDeviation.isNegative ? -hipDeviation : hipDeviation;
  }
}
