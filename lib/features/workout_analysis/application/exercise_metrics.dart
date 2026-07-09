import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum RangeRepSide { left, right }

/// Raw range-rep support signals kept separate from the legacy engine inputs.
class RangeRepFormSignals {
  const RangeRepFormSignals({
    this.torsoAngle,
    this.depthMetric,
    this.alignmentMetric,
    this.stabilityMetric,
    this.lockoutMetric,
    this.bottomControlMetric,
  });

  final double? torsoAngle;
  final double? depthMetric;
  final double? alignmentMetric;
  final double? stabilityMetric;
  final double? lockoutMetric;
  final double? bottomControlMetric;

  bool get hasAnyValue =>
      torsoAngle != null ||
      depthMetric != null ||
      alignmentMetric != null ||
      stabilityMetric != null ||
      lockoutMetric != null ||
      bottomControlMetric != null;
}

class RangeRepSideMetrics {
  const RangeRepSideMetrics({
    required this.side,
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    this.sideConfidence,
    this.formSignals,
  });

  const RangeRepSideMetrics.unavailable(this.side)
    : primaryAngle = 180.0,
      formMetric = 90.0,
      hasPrimaryAngle = false,
      hasFormMetric = false,
      sideConfidence = null,
      formSignals = null;

  final RangeRepSide side;
  final double primaryAngle;
  final double formMetric;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final double? sideConfidence;
  final RangeRepFormSignals? formSignals;

  int get coverageScore => (hasPrimaryAngle ? 1 : 0) + (hasFormMetric ? 1 : 0);
}

class ExerciseMetrics {
  const ExerciseMetrics({
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.hasPose,
    required this.landmarks,
    required this.leftRangeRepMetrics,
    required this.rightRangeRepMetrics,
    this.bodyLineAngle,
    this.armSupportAngle,
    this.legExtensionAngle,
  });

  const ExerciseMetrics.noPose()
    : primaryAngle = 180.0,
      formMetric = 90.0,
      hasPrimaryAngle = false,
      hasFormMetric = false,
      hasPose = false,
      landmarks = const <PoseLandmark>[],
      leftRangeRepMetrics = const RangeRepSideMetrics.unavailable(
        RangeRepSide.left,
      ),
      rightRangeRepMetrics = const RangeRepSideMetrics.unavailable(
        RangeRepSide.right,
      ),
      bodyLineAngle = null,
      armSupportAngle = null,
      legExtensionAngle = null;

  final double primaryAngle;
  final double formMetric;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final bool hasPose;
  final List<PoseLandmark> landmarks;
  final RangeRepSideMetrics leftRangeRepMetrics;
  final RangeRepSideMetrics rightRangeRepMetrics;
  final double? bodyLineAngle;
  final double? armSupportAngle;
  final double? legExtensionAngle;
}
