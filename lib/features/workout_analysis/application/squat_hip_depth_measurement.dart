import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Measures the selected side's normalized hip-depth signal relative to the
/// knee in the 2D image plane.
///
/// The result is the signed vertical difference `(kneeY - hipY)` normalized by
/// the hip-to-knee segment length, producing a scale-independent value in the
/// range `[-1, 1]` when landmarks are present. Positive values mean the hip is
/// above the knee in the image, zero means level, and negative values mean the
/// hip has dropped below the knee. This class is measurement-only and does not
/// apply technique thresholds, validation, scoring, or feedback.
class SquatHipDepthMeasurement {
  const SquatHipDepthMeasurement();

  double? measure(Pose pose, {required RangeRepSide side}) {
    final hipType = resolveRangeRepLandmarkForSide(PoseLandmarkType.leftHip, side);
    final kneeType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftKnee,
      side,
    );
    final hip = pose.landmarks[hipType];
    final knee = pose.landmarks[kneeType];

    if (hip == null || knee == null) {
      return null;
    }

    final dx = knee.x - hip.x;
    final dy = knee.y - hip.y;
    final segmentLength = math.sqrt(dx * dx + dy * dy);
    if (segmentLength == 0) {
      return null;
    }

    return dy / segmentLength;
  }
}
