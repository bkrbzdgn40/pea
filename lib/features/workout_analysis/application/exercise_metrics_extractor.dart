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
    final leftRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.left,
    );
    final rightRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.right,
    );
    final bodyLineAngle = _calculateBodyLineAngle(pose, engineKind);
    final armSupportAngle = _calculateArmSupportAngle(pose, engineKind);
    final legExtensionAngle = _calculateLegExtensionAngle(pose, engineKind);

    return ExerciseMetrics(
      primaryAngle: leftRangeRepMetrics.primaryAngle,
      formMetric: leftRangeRepMetrics.formMetric,
      hasPrimaryAngle: leftRangeRepMetrics.hasPrimaryAngle,
      hasFormMetric: leftRangeRepMetrics.hasFormMetric,
      bodyLineAngle: bodyLineAngle,
      armSupportAngle: armSupportAngle,
      legExtensionAngle: legExtensionAngle,
      hasPose: true,
      landmarks: pose.landmarks.values.toList(),
      leftRangeRepMetrics: leftRangeRepMetrics,
      rightRangeRepMetrics: rightRangeRepMetrics,
    );
  }

  RangeRepSideMetrics _extractRangeRepSideMetrics(
    Pose pose,
    ExerciseConfig config,
    RangeRepSide side,
  ) {
    final primaryAngle = _tryCalculatePrimaryAngle(pose, config, side: side);
    final formMetric = _tryCalculateFormMetric(pose, side: side);
    final formSignals = _extractRangeRepFormSignals(
      pose,
      config,
      side: side,
      primaryAngle: primaryAngle,
      formMetric: formMetric,
    );

    return RangeRepSideMetrics(
      side: side,
      primaryAngle: primaryAngle ?? 180.0,
      formMetric: formMetric ?? 90.0,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
      formSignals: formSignals,
    );
  }

  RangeRepFormSignals? _extractRangeRepFormSignals(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
    required double? primaryAngle,
    required double? formMetric,
  }) {
    if (!_supportsSquatFormSignals(config)) {
      return null;
    }

    // Reuse only the raw squat angles we already trust in this compatibility
    // step. More interpretive signals stay null until a later scoring pass.
    final signals = RangeRepFormSignals(
      torsoAngle: formMetric,
      depthMetric: primaryAngle,
      alignmentMetric: _tryCalculateSideAngle(
        pose,
        side: side,
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      stabilityMetric: null,
      lockoutMetric: _tryCalculateSideAngle(
        pose,
        side: side,
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
      bottomControlMetric: null,
    );

    return signals.hasAnyValue ? signals : null;
  }

  double? _tryCalculatePrimaryAngle(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
  }) {
    final p1 = pose.landmarks[_landmarkTypeForSide(config.joint1, side)];
    final mid = pose.landmarks[_landmarkTypeForSide(config.primaryJoint, side)];
    final p2 = pose.landmarks[_landmarkTypeForSide(config.joint2, side)];

    if (p1 != null && mid != null && p2 != null) {
      return AngleCalculator.calculate(
        math.Point(p1.x, p1.y),
        math.Point(mid.x, mid.y),
        math.Point(p2.x, p2.y),
      );
    }

    return null;
  }

  double? _tryCalculateFormMetric(Pose pose, {required RangeRepSide side}) {
    final shoulder = pose
        .landmarks[_landmarkTypeForSide(PoseLandmarkType.leftShoulder, side)];
    final hip =
        pose.landmarks[_landmarkTypeForSide(PoseLandmarkType.leftHip, side)];
    final knee =
        pose.landmarks[_landmarkTypeForSide(PoseLandmarkType.leftKnee, side)];

    if (shoulder != null && hip != null && knee != null) {
      return AngleCalculator.calculate(
        math.Point(shoulder.x, shoulder.y),
        math.Point(hip.x, hip.y),
        math.Point(knee.x, knee.y),
      );
    }

    return null;
  }

  double? _tryCalculateSideAngle(
    Pose pose, {
    required RangeRepSide side,
    required PoseLandmarkType first,
    required PoseLandmarkType middle,
    required PoseLandmarkType last,
  }) {
    return _tryCalculateAngle(
      pose,
      _landmarkTypeForSide(first, side),
      _landmarkTypeForSide(middle, side),
      _landmarkTypeForSide(last, side),
    );
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

  PoseLandmarkType _landmarkTypeForSide(
    PoseLandmarkType landmarkType,
    RangeRepSide side,
  ) {
    if (side == RangeRepSide.left) {
      return landmarkType;
    }

    switch (landmarkType) {
      case PoseLandmarkType.leftShoulder:
        return PoseLandmarkType.rightShoulder;
      case PoseLandmarkType.leftElbow:
        return PoseLandmarkType.rightElbow;
      case PoseLandmarkType.leftWrist:
        return PoseLandmarkType.rightWrist;
      case PoseLandmarkType.leftHip:
        return PoseLandmarkType.rightHip;
      case PoseLandmarkType.leftKnee:
        return PoseLandmarkType.rightKnee;
      case PoseLandmarkType.leftAnkle:
        return PoseLandmarkType.rightAnkle;
      case PoseLandmarkType.rightShoulder:
        return PoseLandmarkType.leftShoulder;
      case PoseLandmarkType.rightElbow:
        return PoseLandmarkType.leftElbow;
      case PoseLandmarkType.rightWrist:
        return PoseLandmarkType.leftWrist;
      case PoseLandmarkType.rightHip:
        return PoseLandmarkType.leftHip;
      case PoseLandmarkType.rightKnee:
        return PoseLandmarkType.leftKnee;
      case PoseLandmarkType.rightAnkle:
        return PoseLandmarkType.leftAnkle;
      default:
        return landmarkType;
    }
  }

  bool _supportsHoldAlignmentMetrics(EngineKind engineKind) {
    return engineKind == EngineKind.hold;
  }

  bool _supportsSquatFormSignals(ExerciseConfig config) {
    return config.primaryJoint == PoseLandmarkType.leftKnee &&
        config.joint1 == PoseLandmarkType.leftHip &&
        config.joint2 == PoseLandmarkType.leftAnkle;
  }
}
