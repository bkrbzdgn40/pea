import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Measures selected-side hip height relative to knee height in the 2D image
/// plane, normalized by the knee-to-ankle segment length.
///
/// Image coordinates increase downward on the y axis, so positive values mean
/// the hip is visually above the knee, zero means equal image height, and
/// negative values mean the hip is visually below the knee. The result is
/// dimensionless and intentionally carries no validation, scoring, or coaching
/// threshold semantics.
class SquatHipDepthMeasurement {
  const SquatHipDepthMeasurement();

  double? measure(Pose pose, {required RangeRepSide side}) {
    final hipType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftHip,
      side,
    );
    final kneeType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftKnee,
      side,
    );
    final ankleType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftAnkle,
      side,
    );
    final hip = pose.landmarks[hipType];
    final knee = pose.landmarks[kneeType];
    final ankle = pose.landmarks[ankleType];

    if (hip == null || knee == null || ankle == null) {
      return null;
    }

    final dx = ankle.x - knee.x;
    final dy = ankle.y - knee.y;
    final normalizationLength = math.sqrt((dx * dx) + (dy * dy));
    if (normalizationLength == 0.0) {
      return null;
    }

    return (knee.y - hip.y) / normalizationLength;
  }
}
