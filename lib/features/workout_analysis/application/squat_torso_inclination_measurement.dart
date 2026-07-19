import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/image_plane_geometry.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Measures the selected side's shoulder-to-hip torso inclination in the 2D
/// image plane.
///
/// The result is direction-independent and ranges from 0 degrees for a vertical
/// torso segment to 90 degrees for a horizontal torso segment. It is a physical
/// measurement only: this class does not apply technique thresholds, validation,
/// scoring, feedback, or rep-phase comparisons.
class SquatTorsoInclinationMeasurement {
  const SquatTorsoInclinationMeasurement();

  double? measure(Pose pose, {required RangeRepSide side}) {
    final shoulderType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftShoulder,
      side,
    );
    final hipType = resolveRangeRepLandmarkForSide(
      PoseLandmarkType.leftHip,
      side,
    );
    final shoulder = pose.landmarks[shoulderType];
    final hip = pose.landmarks[hipType];

    if (shoulder == null || hip == null) {
      return null;
    }

    return imagePlaneInclination(
      math.Point<double>(shoulder.x, shoulder.y),
      math.Point<double>(hip.x, hip.y),
    );
  }
}
