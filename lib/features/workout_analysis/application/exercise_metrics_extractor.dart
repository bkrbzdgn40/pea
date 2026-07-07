import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import 'engine_kind.dart';
import '../domain/models/exercise_config.dart';
import 'exercise_metrics.dart';

/// Converts a detected pose into the measurement signals the current engine uses.
class ExerciseMetricsExtractor {
  const ExerciseMetricsExtractor();

  ExerciseMetrics extract(
    Pose pose,
    ExerciseConfig config, {
    required EngineKind engineKind,
  }) {
    final primaryAngle = _tryCalculatePrimaryAngle(pose, config);
    final formMetric = _tryCalculateFormMetric(pose);
    final bodyLineAngle = _calculateBodyLineAngle(pose, engineKind);
    final armSupportAngle = _calculateArmSupportAngle(pose, engineKind);
    final legExtensionAngle = _calculateLegExtensionAngle(pose, engineKind);

    return ExerciseMetrics(
      primaryAngle: primaryAngle ?? 180.0,
      formMetric: formMetric ?? 90.0,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
      bodyLineAngle: bodyLineAngle,
      armSupportAngle: armSupportAngle,
      legExtensionAngle: legExtensionAngle,
      hasPose: true,
      landmarks: pose.landmarks.values.toList(),
    );
  }

  double? _tryCalculatePrimaryAngle(Pose pose, ExerciseConfig config) {
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

    return null;
  }

  double? _tryCalculateFormMetric(Pose pose) {
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

    return null;
  }

  double? _calculateBodyLineAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle,
    );
  }

  double? _calculateArmSupportAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );
  }

  double? _calculateLegExtensionAngle(Pose pose, EngineKind engineKind) {
    if (!_supportsHoldAlignmentMetrics(engineKind)) {
      return null;
    }

    return _tryCalculateAngle(
      pose,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
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

  bool _supportsHoldAlignmentMetrics(EngineKind engineKind) {
    return engineKind == EngineKind.hold;
  }
}
