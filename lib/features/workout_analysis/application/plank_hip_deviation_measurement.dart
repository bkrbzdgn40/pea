import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';

/// Measures selected-side plank hip deviation from the shoulder-to-ankle line
/// in the 2D image plane.
///
/// The result is an unsigned, dimensionless deviation normalized by the
/// shoulder-to-ankle segment length. It intentionally carries no validation,
/// severity, scoring, or coaching threshold semantics.
class PlankHipDeviationMeasurement {
  const PlankHipDeviationMeasurement();

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
    final hip =
        landmarksByType[isLeft
            ? PoseLandmarkType.leftHip
            : PoseLandmarkType.rightHip];
    final ankle =
        landmarksByType[isLeft
            ? PoseLandmarkType.leftAnkle
            : PoseLandmarkType.rightAnkle];

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
