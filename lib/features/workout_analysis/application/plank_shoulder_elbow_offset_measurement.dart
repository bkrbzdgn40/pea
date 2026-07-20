import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';

/// Measures selected-side plank shoulder-to-elbow stacking deviation in the
/// 2D image plane.
///
/// The result is the absolute horizontal shoulder-elbow offset normalized by
/// the shoulder-elbow segment length. A value of zero means the two landmarks
/// are vertically stacked in image coordinates. The result is dimensionless
/// and intentionally carries no validation, severity, or coaching threshold
/// semantics.
class PlankShoulderElbowOffsetMeasurement {
  const PlankShoulderElbowOffsetMeasurement();

  double? measureLandmarks(
    List<PoseLandmark> landmarks, {
    required HoldSide side,
  }) {
    final landmarksByType = <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    };
    final isLeft = side == HoldSide.left;
    final shoulder =
        landmarksByType[isLeft
            ? PoseLandmarkType.leftShoulder
            : PoseLandmarkType.rightShoulder];
    final elbow =
        landmarksByType[isLeft
            ? PoseLandmarkType.leftElbow
            : PoseLandmarkType.rightElbow];

    if (shoulder == null || elbow == null) {
      return null;
    }

    final shoulderPoint = math.Point<double>(shoulder.x, shoulder.y);
    final elbowPoint = math.Point<double>(elbow.x, elbow.y);
    return normalizedAxisOffset(
      point: elbowPoint,
      referencePoint: shoulderPoint,
      normalizationStart: shoulderPoint,
      normalizationEnd: elbowPoint,
      axis: ImagePlaneAxis.horizontal,
    );
  }
}
