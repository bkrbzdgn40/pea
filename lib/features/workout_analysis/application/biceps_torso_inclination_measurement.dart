import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Measures shoulder-to-hip torso inclination for biceps-curl analysis.
///
/// Bilateral curls use the mean of the available left/right physical
/// measurements. This is a threshold-free measurement and does not itself
/// classify torso swing as good or bad.
class BicepsTorsoInclinationMeasurement {
  const BicepsTorsoInclinationMeasurement();

  double? measureSide(Pose pose, {required RangeRepSide side}) {
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

  double? measureBilateral(Pose pose) {
    final left = measureSide(pose, side: RangeRepSide.left);
    final right = measureSide(pose, side: RangeRepSide.right);
    final measurements = <double>[?left, ?right];
    if (measurements.isEmpty) {
      return null;
    }

    return measurements.reduce((left, right) => left + right) /
        measurements.length;
  }
}
