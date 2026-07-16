import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/hold_side.dart';

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

abstract class RangeRepAnalysisMetrics {
  const RangeRepAnalysisMetrics({
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    this.formSignals,
  });

  final double primaryAngle;
  final double formMetric;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final RangeRepFormSignals? formSignals;
}

class RangeRepSideMetrics extends RangeRepAnalysisMetrics {
  const RangeRepSideMetrics({
    required this.side,
    required super.primaryAngle,
    required super.formMetric,
    required super.hasPrimaryAngle,
    required super.hasFormMetric,
    this.sideConfidence,
    super.formSignals,
  });

  const RangeRepSideMetrics.unavailable(this.side)
    : sideConfidence = null,
      super(
        primaryAngle: 180.0,
        formMetric: 90.0,
        hasPrimaryAngle: false,
        hasFormMetric: false,
      );

  final RangeRepSide side;
  final double? sideConfidence;

  int get coverageScore => (hasPrimaryAngle ? 1 : 0) + (hasFormMetric ? 1 : 0);
}

class RangeRepBilateralMetrics extends RangeRepAnalysisMetrics {
  const RangeRepBilateralMetrics({
    required super.primaryAngle,
    required super.formMetric,
    required super.hasPrimaryAngle,
    required super.hasFormMetric,
    required this.leftPrimaryAngle,
    required this.rightPrimaryAngle,
    required this.leftFormScore,
    required this.rightFormScore,
    required this.syncScore,
    super.formSignals,
  });

  final double? leftPrimaryAngle;
  final double? rightPrimaryAngle;
  final double? leftFormScore;
  final double? rightFormScore;
  final double? syncScore;
}

class ExerciseMetrics {
  static const Object _holdSideUnset = Object();
  static const Object _bilateralRangeRepMetricsUnset = Object();

  const ExerciseMetrics({
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.hasPose,
    required this.landmarks,
    required this.leftRangeRepMetrics,
    required this.rightRangeRepMetrics,
    this.bilateralRangeRepMetrics,
    this.bodyLineAngle,
    this.armSupportAngle,
    this.legExtensionAngle,
    this.holdSide,
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
      bilateralRangeRepMetrics = null,
      bodyLineAngle = null,
      armSupportAngle = null,
      legExtensionAngle = null,
      holdSide = null;

  final double primaryAngle;
  final double formMetric;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final bool hasPose;
  final List<PoseLandmark> landmarks;
  final RangeRepSideMetrics leftRangeRepMetrics;
  final RangeRepSideMetrics rightRangeRepMetrics;
  final RangeRepBilateralMetrics? bilateralRangeRepMetrics;
  final double? bodyLineAngle;
  final double? armSupportAngle;
  final double? legExtensionAngle;
  final HoldSide? holdSide;

  ExerciseMetrics copyWith({
    double? primaryAngle,
    double? formMetric,
    bool? hasPrimaryAngle,
    bool? hasFormMetric,
    bool? hasPose,
    List<PoseLandmark>? landmarks,
    RangeRepSideMetrics? leftRangeRepMetrics,
    RangeRepSideMetrics? rightRangeRepMetrics,
    Object? bilateralRangeRepMetrics = _bilateralRangeRepMetricsUnset,
    double? bodyLineAngle,
    double? armSupportAngle,
    double? legExtensionAngle,
    Object? holdSide = _holdSideUnset,
  }) {
    return ExerciseMetrics(
      primaryAngle: primaryAngle ?? this.primaryAngle,
      formMetric: formMetric ?? this.formMetric,
      hasPrimaryAngle: hasPrimaryAngle ?? this.hasPrimaryAngle,
      hasFormMetric: hasFormMetric ?? this.hasFormMetric,
      hasPose: hasPose ?? this.hasPose,
      landmarks: landmarks ?? this.landmarks,
      leftRangeRepMetrics: leftRangeRepMetrics ?? this.leftRangeRepMetrics,
      rightRangeRepMetrics: rightRangeRepMetrics ?? this.rightRangeRepMetrics,
      bilateralRangeRepMetrics:
          bilateralRangeRepMetrics == _bilateralRangeRepMetricsUnset
          ? this.bilateralRangeRepMetrics
          : bilateralRangeRepMetrics as RangeRepBilateralMetrics?,
      bodyLineAngle: bodyLineAngle ?? this.bodyLineAngle,
      armSupportAngle: armSupportAngle ?? this.armSupportAngle,
      legExtensionAngle: legExtensionAngle ?? this.legExtensionAngle,
      holdSide: holdSide == _holdSideUnset
          ? this.holdSide
          : holdSide as HoldSide?,
    );
  }
}
