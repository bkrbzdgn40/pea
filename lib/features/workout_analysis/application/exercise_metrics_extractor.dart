import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import '../domain/models/exercise_config.dart';
import 'exercise_metrics.dart';

/// Converts a detected pose into the measurement signals the current engine uses.
class ExerciseMetricsExtractor {
  const ExerciseMetricsExtractor();

  ExerciseMetrics extract(Pose pose, ExerciseConfig config) {
    final bodyLineAngle = _calculateBodyLineAngle(pose, config);
    final armSupportAngle = _calculateArmSupportAngle(pose, config);

    return ExerciseMetrics(
      primaryAngle: _calculatePrimaryAngle(pose, config),
      formMetric: _calculateFormMetric(pose),
      bodyLineAngle: bodyLineAngle,
      armSupportAngle: armSupportAngle,
      hasPose: true,
      landmarks: pose.landmarks.values.toList(),
    );
  }

  double _calculatePrimaryAngle(Pose pose, ExerciseConfig config) {
    final p1 = pose.landmarks[config.joint1];
    final mid = pose.landmarks[config.primaryJoint];
    final p2 = pose.landmarks[config.joint2];

    if (p1 != null && mid != null && p2 != null) {
      return AngleCalculator.calculate(
        math.Point(p1.x, p1.y),
        math.Point(mid.x, mid.y),
        math.Point(p2.x, p2.y),
      );
    }

    // Keep the existing neutral fallback for incomplete joint sets.
    return 180.0;
  }

  double _calculateFormMetric(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];

    if (shoulder != null && hip != null && knee != null) {
      return AngleCalculator.calculate(
        math.Point(shoulder.x, shoulder.y),
        math.Point(hip.x, hip.y),
        math.Point(knee.x, knee.y),
      );
    }

    // Preserve the current upright-ish fallback used for squat form checks.
    return 90.0;
  }

  double? _calculateBodyLineAngle(Pose pose, ExerciseConfig config) {
    if (!_isPlankConfig(config)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle,
    );
  }

  double? _calculateArmSupportAngle(Pose pose, ExerciseConfig config) {
    if (!_isPlankConfig(config)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
  }

  double? _tryCalculateAngle(
    Pose pose,
    PoseLandmarkType first,
    PoseLandmarkType middle,
    PoseLandmarkType last,
  ) {
    final firstLandmark = pose.landmarks[first];
    final middleLandmark = pose.landmarks[middle];
    final lastLandmark = pose.landmarks[last];

    if (firstLandmark == null ||
        middleLandmark == null ||
        lastLandmark == null) {
      return null;
    }

    return AngleCalculator.calculate(
      math.Point(firstLandmark.x, firstLandmark.y),
      math.Point(middleLandmark.x, middleLandmark.y),
      math.Point(lastLandmark.x, lastLandmark.y),
    );
  }

  bool _isPlankConfig(ExerciseConfig config) {
    return config.name.trim().toLowerCase() == 'plank';
  }
}
