import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/hold_side.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_signal_values.dart';
import '../domain/models/measurement_confidence_breakdown.dart';
import 'exercise_metric_registry.dart';

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
    this.measurementConfidence,
    this.formSignals,
  });

  final double primaryAngle;
  final double formMetric;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final MeasurementConfidenceBreakdown? measurementConfidence;
  final RangeRepFormSignals? formSignals;
}

class RangeRepSideMetrics extends RangeRepAnalysisMetrics {
  static const Object _sideConfidenceUnset = Object();
  static const Object _measurementConfidenceUnset = Object();

  // ignore: use_super_parameters
  RangeRepSideMetrics({
    required this.side,
    required double primaryAngle,
    required double formMetric,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
    double? sideConfidence,
    MeasurementConfidenceBreakdown? measurementConfidence,
    RangeRepFormSignals? formSignals,
  }) : assert(
         sideConfidence == null ||
             measurementConfidence == null ||
             sideConfidence == measurementConfidence.combined,
       ),
       super(
         primaryAngle: primaryAngle,
         formMetric: formMetric,
         hasPrimaryAngle: hasPrimaryAngle,
         hasFormMetric: hasFormMetric,
         measurementConfidence:
             measurementConfidence ??
             (sideConfidence == null
                 ? null
                 : MeasurementConfidenceBreakdown.legacyScalar(sideConfidence)),
         formSignals: formSignals,
       );

  const RangeRepSideMetrics.unavailable(this.side)
    : super(
        primaryAngle: 180.0,
        formMetric: 90.0,
        hasPrimaryAngle: false,
        hasFormMetric: false,
      );

  final RangeRepSide side;

  /// Temporary compatibility view. Confidence V2 owns the actual value.
  double? get sideConfidence => measurementConfidence?.combined;

  int get coverageScore => (hasPrimaryAngle ? 1 : 0) + (hasFormMetric ? 1 : 0);

  RangeRepSideMetrics copyWith({
    double? primaryAngle,
    double? formMetric,
    bool? hasPrimaryAngle,
    bool? hasFormMetric,
    Object? sideConfidence = _sideConfidenceUnset,
    Object? measurementConfidence = _measurementConfidenceUnset,
    RangeRepFormSignals? formSignals,
  }) {
    final resolvedMeasurementConfidence =
        measurementConfidence != _measurementConfidenceUnset
        ? measurementConfidence as MeasurementConfidenceBreakdown?
        : sideConfidence != _sideConfidenceUnset
        ? (sideConfidence == null
              ? null
              : MeasurementConfidenceBreakdown.legacyScalar(
                  sideConfidence as double,
                ))
        : this.measurementConfidence;
    return RangeRepSideMetrics(
      side: side,
      primaryAngle: primaryAngle ?? this.primaryAngle,
      formMetric: formMetric ?? this.formMetric,
      hasPrimaryAngle: hasPrimaryAngle ?? this.hasPrimaryAngle,
      hasFormMetric: hasFormMetric ?? this.hasFormMetric,
      measurementConfidence: resolvedMeasurementConfidence,
      formSignals: formSignals ?? this.formSignals,
    );
  }
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
    super.measurementConfidence,
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
  static const Object _holdSignalOverrideUnset = Object();

  ExerciseMetrics({
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPrimaryAngle,
    required this.hasFormMetric,
    required this.hasPose,
    required this.landmarks,
    required this.leftRangeRepMetrics,
    required this.rightRangeRepMetrics,
    this.bilateralRangeRepMetrics,
    HoldSignalValues? holdSignalValues,
    double? bodyLineAngle,
    double? armSupportAngle,
    double? legExtensionAngle,
    this.holdSide,
  }) : holdSignalValues =
           holdSignalValues ??
           HoldSignalValues.legacy(
             alignment: bodyLineAngle,
             support: armSupportAngle,
             extension: legExtensionAngle,
           );

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
      holdSignalValues = const HoldSignalValues.empty(),
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
  final HoldSignalValues holdSignalValues;
  final HoldSide? holdSide;

  double? get bodyLineAngle => holdSignalValues.valueFor(HoldSignal.alignment);

  double? get armSupportAngle => holdSignalValues.valueFor(HoldSignal.support);

  double? get legExtensionAngle =>
      holdSignalValues.valueFor(HoldSignal.extension);

  /// Canonical frame-level metrics currently exposed by the legacy extractor.
  ///
  /// Future engines can add repetition- and session-scoped snapshots without
  /// changing callers that consume the registry-backed metric contract.
  ExerciseMetricSnapshot get frameMetricSnapshot {
    final builder = ExerciseMetricSnapshotBuilder(
      scope: ExerciseMetricScope.frame,
    );
    if (hasPrimaryAngle) {
      builder.set(ExerciseMetricRegistry.primaryMovement, primaryAngle);
    }
    if (hasFormMetric) {
      builder.set(ExerciseMetricRegistry.form, formMetric);
    }
    return builder.build();
  }

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
    HoldSignalValues? holdSignalValues,
    Object? bodyLineAngle = _holdSignalOverrideUnset,
    Object? armSupportAngle = _holdSignalOverrideUnset,
    Object? legExtensionAngle = _holdSignalOverrideUnset,
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
      holdSignalValues:
          holdSignalValues ??
          this.holdSignalValues.mergedWith(<HoldSignal, double?>{
            if (bodyLineAngle != _holdSignalOverrideUnset)
              HoldSignal.alignment: bodyLineAngle as double?,
            if (armSupportAngle != _holdSignalOverrideUnset)
              HoldSignal.support: armSupportAngle as double?,
            if (legExtensionAngle != _holdSignalOverrideUnset)
              HoldSignal.extension: legExtensionAngle as double?,
          }),
      holdSide: holdSide == _holdSideUnset
          ? this.holdSide
          : holdSide as HoldSide?,
    );
  }
}
