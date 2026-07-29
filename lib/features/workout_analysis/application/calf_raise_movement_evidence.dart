import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/image_plane_geometry.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';
import 'range_rep_extension_pose_utils.dart';

/// Selected-side pose geometry used to decide whether an ankle-angle excursion
/// is a real calf raise.
class CalfRaisePoseSample {
  const CalfRaisePoseSample({
    required this.heelToForefootSpan,
    required this.ankleToForefootSpan,
    required this.hipToForefootSpan,
    required this.bodyScale,
    required this.forefootX,
    required this.forefootY,
    required this.torsoInclinationDegrees,
  });

  final double heelToForefootSpan;
  final double ankleToForefootSpan;
  final double hipToForefootSpan;
  final double bodyScale;
  final double forefootX;
  final double forefootY;
  final double torsoInclinationDegrees;
}

/// Auditable movement-identity evidence for a candidate Calf Raise frame.
class CalfRaiseMovementEvidence {
  const CalfRaiseMovementEvidence({
    required this.heelElevationRatio,
    required this.ankleElevationRatio,
    required this.hipElevationRatio,
    required this.forefootDriftRatio,
    required this.torsoInclinationDeltaDegrees,
    required this.isCalfRaise,
  });

  const CalfRaiseMovementEvidence.unavailable()
    : heelElevationRatio = null,
      ankleElevationRatio = null,
      hipElevationRatio = null,
      forefootDriftRatio = null,
      torsoInclinationDeltaDegrees = null,
      isCalfRaise = false;

  final double? heelElevationRatio;
  final double? ankleElevationRatio;
  final double? hipElevationRatio;
  final double? forefootDriftRatio;
  final double? torsoInclinationDeltaDegrees;
  final bool isCalfRaise;
}

/// Converts pose landmarks into Calf Raise movement-identity evidence.
///
/// All displacement ratios use the neutral hip-to-forefoot distance as scale.
/// Heel elevation is the identity signal. Ankle and hip elevation reject
/// isolated foot-landmark jitter, while forefoot drift and torso inclination
/// reject translation and hip-hinge geometry.
class CalfRaiseMovementEvidencePolicy {
  const CalfRaiseMovementEvidencePolicy({
    this.minimumHeelElevationRatio = 0.012,
    this.minimumAnkleElevationRatio = 0.012,
    this.minimumHipElevationRatio = 0.008,
    this.maximumForefootDriftRatio = 0.04,
    this.maximumTorsoInclinationDeltaDegrees = 12.0,
  });

  static const double _minimumScale = 0.000001;

  final double minimumHeelElevationRatio;
  final double minimumAnkleElevationRatio;
  final double minimumHipElevationRatio;
  final double maximumForefootDriftRatio;
  final double maximumTorsoInclinationDeltaDegrees;

  CalfRaisePoseSample? measure(ExerciseMetrics metrics, RangeRepSide side) {
    final pose = poseFromLandmarks(metrics.landmarks);

    PoseLandmark? landmark(PoseLandmarkType leftType) {
      return pose.landmarks[resolveRangeRepLandmarkForSide(leftType, side)];
    }

    final shoulder = landmark(PoseLandmarkType.leftShoulder);
    final hip = landmark(PoseLandmarkType.leftHip);
    final ankle = landmark(PoseLandmarkType.leftAnkle);
    final heel = landmark(PoseLandmarkType.leftHeel);
    final forefoot = landmark(PoseLandmarkType.leftFootIndex);
    if (shoulder == null ||
        hip == null ||
        ankle == null ||
        heel == null ||
        forefoot == null) {
      return null;
    }

    final torsoInclination = imagePlaneInclination(
      math.Point<double>(shoulder.x, shoulder.y),
      math.Point<double>(hip.x, hip.y),
    );
    if (torsoInclination == null) {
      return null;
    }

    return CalfRaisePoseSample(
      heelToForefootSpan: forefoot.y - heel.y,
      ankleToForefootSpan: forefoot.y - ankle.y,
      hipToForefootSpan: forefoot.y - hip.y,
      bodyScale: _distance(hip.x, hip.y, forefoot.x, forefoot.y),
      forefootX: forefoot.x,
      forefootY: forefoot.y,
      torsoInclinationDegrees: torsoInclination,
    );
  }

  CalfRaiseMovementEvidence evaluate({
    required CalfRaisePoseSample? baseline,
    required CalfRaisePoseSample? current,
  }) {
    if (baseline == null ||
        current == null ||
        baseline.bodyScale <= _minimumScale) {
      return const CalfRaiseMovementEvidence.unavailable();
    }

    final scale = baseline.bodyScale;
    final heelElevationRatio =
        (current.heelToForefootSpan - baseline.heelToForefootSpan) / scale;
    final ankleElevationRatio =
        (current.ankleToForefootSpan - baseline.ankleToForefootSpan) / scale;
    final hipElevationRatio =
        (current.hipToForefootSpan - baseline.hipToForefootSpan) / scale;
    final forefootDriftRatio =
        _distance(
          current.forefootX,
          current.forefootY,
          baseline.forefootX,
          baseline.forefootY,
        ) /
        scale;
    final torsoInclinationDeltaDegrees =
        (current.torsoInclinationDegrees - baseline.torsoInclinationDegrees)
            .abs();
    final isCalfRaise =
        heelElevationRatio >= minimumHeelElevationRatio &&
        ankleElevationRatio >= minimumAnkleElevationRatio &&
        hipElevationRatio >= minimumHipElevationRatio &&
        forefootDriftRatio <= maximumForefootDriftRatio &&
        torsoInclinationDeltaDegrees <= maximumTorsoInclinationDeltaDegrees;

    return CalfRaiseMovementEvidence(
      heelElevationRatio: heelElevationRatio,
      ankleElevationRatio: ankleElevationRatio,
      hipElevationRatio: hipElevationRatio,
      forefootDriftRatio: forefootDriftRatio,
      torsoInclinationDeltaDegrees: torsoInclinationDeltaDegrees,
      isCalfRaise: isCalfRaise,
    );
  }

  CalfRaisePoseSample medianSample(List<CalfRaisePoseSample> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'must not be empty');
    }
    return CalfRaisePoseSample(
      heelToForefootSpan: _median(
        samples.map((sample) => sample.heelToForefootSpan),
      ),
      ankleToForefootSpan: _median(
        samples.map((sample) => sample.ankleToForefootSpan),
      ),
      hipToForefootSpan: _median(
        samples.map((sample) => sample.hipToForefootSpan),
      ),
      bodyScale: _median(samples.map((sample) => sample.bodyScale)),
      forefootX: _median(samples.map((sample) => sample.forefootX)),
      forefootY: _median(samples.map((sample) => sample.forefootY)),
      torsoInclinationDegrees: _median(
        samples.map((sample) => sample.torsoInclinationDegrees),
      ),
    );
  }

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}
