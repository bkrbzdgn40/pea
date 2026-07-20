import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';
import 'pose_landmark_mirror.dart';

/// Measures selected-side horizontal shoulder-to-elbow offset in the image
/// plane, normalized by the shoulder-to-elbow segment length.
///
/// In the preferred side view this is a physical support-stacking signal. The
/// result carries no acceptance or coaching threshold; legacy elbow-angle
/// gates remain separate from this technique measurement.
class PlankShoulderElbowOffsetMeasurement {
  const PlankShoulderElbowOffsetMeasurement();

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

    final shoulderPoint = math.Point<double>(shoulder.x, shoulder.y);
    final elbowPoint = math.Point<double>(elbow.x, elbow.y);
    return normalizedAxisOffset(
      point: shoulderPoint,
      referencePoint: elbowPoint,
      normalizationStart: shoulderPoint,
      normalizationEnd: elbowPoint,
      axis: ImagePlaneAxis.horizontal,
    );
  }
}
