import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/core/utils/image_plane_geometry.dart';

import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Measures selected-side hip deviation from the shoulder-to-ankle line in the
/// 2D image plane, normalized by the shoulder-to-ankle segment length.
///
/// This produces a dimensionless generic deviation magnitude without assigning
/// anatomical coaching meaning such as sag or pike. The result is not clamped
/// and intentionally carries no validation, scoring, or feedback thresholds.
class PushUpHipDeviationMeasurement {
  const PushUpHipDeviationMeasurement();

  double? measure(Pose pose, {required RangeRepSide side}) {
    final shoulderType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftShoulder,
      side,
    );
    final hipType = resolveRangeRepLandmarkForSide(PoseLandmarkType.leftHip, side);
    final ankleType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftAnkle,
      side,
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
