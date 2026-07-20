import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import '../domain/models/hold_side.dart';
import 'pose_landmark_mirror.dart';

class HollowHoldLimbElevationMeasurements {
  const HollowHoldLimbElevationMeasurements({
    required this.shoulderElevation,
    required this.heelElevation,
  });

  final double? shoulderElevation;
  final double? heelElevation;
}

/// Produces normalized image-plane limb elevation magnitudes for Hollow Hold.
///
/// These are measurements only. No variation threshold or acceptance decision
/// is embedded here.
class HollowHoldLimbElevationMeasurement {
  const HollowHoldLimbElevationMeasurement();

  HollowHoldLimbElevationMeasurements measure(
    Pose pose, {
    required HoldSide side,
    HoldSide referenceSide = HoldSide.left,
  }) {
    PoseLandmark? landmark(PoseLandmarkType configured) {
      return pose.landmarks[resolveHoldLandmarkForSide(
        configuredLandmark: configured,
        referenceSide: referenceSide,
        targetSide: side,
      )];
    }

    final shoulder = landmark(PoseLandmarkType.leftShoulder);
    final hip = landmark(PoseLandmarkType.leftHip);
    final heel = landmark(PoseLandmarkType.leftHeel);
    if (shoulder == null || hip == null || heel == null) {
      return const HollowHoldLimbElevationMeasurements(
        shoulderElevation: null,
        heelElevation: null,
      );
    }

    final shoulderPoint = math.Point<double>(shoulder.x, shoulder.y);
    final hipPoint = math.Point<double>(hip.x, hip.y);
    final heelPoint = math.Point<double>(heel.x, heel.y);

    return HollowHoldLimbElevationMeasurements(
      shoulderElevation: normalizedAxisOffset(
        point: shoulderPoint,
        referencePoint: hipPoint,
        normalizationStart: shoulderPoint,
        normalizationEnd: heelPoint,
        axis: ImagePlaneAxis.vertical,
      ),
      heelElevation: normalizedAxisOffset(
        point: heelPoint,
        referencePoint: hipPoint,
        normalizationStart: shoulderPoint,
        normalizationEnd: heelPoint,
        axis: ImagePlaneAxis.vertical,
      ),
    );
  }
}
