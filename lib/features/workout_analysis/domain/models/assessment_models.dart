enum AssessmentType { squat, balance, shoulderMobility }

enum AssessmentPhase { idle, active, completed }

enum AssessmentSide { left, right }

sealed class AssessmentObservation {
  const AssessmentObservation({required this.type});

  final AssessmentType type;
}

final class SquatAssessmentObservation extends AssessmentObservation {
  const SquatAssessmentObservation({
    required this.leftKneeAngleDegrees,
    required this.rightKneeAngleDegrees,
    required this.hipDepthRatio,
    required this.torsoInclinationDegrees,
  }) : super(type: AssessmentType.squat);

  final double? leftKneeAngleDegrees;
  final double? rightKneeAngleDegrees;
  final double? hipDepthRatio;
  final double? torsoInclinationDegrees;

  bool get isComplete =>
      leftKneeAngleDegrees != null &&
      rightKneeAngleDegrees != null &&
      hipDepthRatio != null &&
      torsoInclinationDegrees != null;
}

final class BalanceAssessmentObservation extends AssessmentObservation {
  const BalanceAssessmentObservation({
    required this.side,
    required this.capturedAt,
    required this.shoulderCenterXNormalized,
    required this.hipCenterXNormalized,
    required this.raisedFootClearanceRatio,
  }) : super(type: AssessmentType.balance);

  final AssessmentSide side;
  final DateTime capturedAt;
  final double? shoulderCenterXNormalized;
  final double? hipCenterXNormalized;
  final double? raisedFootClearanceRatio;

  bool get isComplete =>
      shoulderCenterXNormalized != null &&
      hipCenterXNormalized != null &&
      raisedFootClearanceRatio != null;
}

final class ShoulderMobilityAssessmentObservation
    extends AssessmentObservation {
  const ShoulderMobilityAssessmentObservation({
    required this.leftElevationDegrees,
    required this.rightElevationDegrees,
    required this.torsoInclinationDegrees,
  }) : super(type: AssessmentType.shoulderMobility);

  final double? leftElevationDegrees;
  final double? rightElevationDegrees;
  final double? torsoInclinationDegrees;

  bool get hasAnyElevation =>
      leftElevationDegrees != null || rightElevationDegrees != null;
}

sealed class AssessmentResult {
  const AssessmentResult({
    required this.type,
    required this.sampleCount,
    required this.hasSufficientData,
  });

  final AssessmentType type;
  final int sampleCount;
  final bool hasSufficientData;
}

final class SquatAssessmentResult extends AssessmentResult {
  const SquatAssessmentResult({
    required super.sampleCount,
    required super.hasSufficientData,
    required this.leftKneeFlexionDegrees,
    required this.rightKneeFlexionDegrees,
    required this.kneeFlexionAsymmetryDegrees,
    required this.deepestHipDepthRatio,
    required this.torsoInclinationAtDeepestDegrees,
  }) : super(type: AssessmentType.squat);

  final double? leftKneeFlexionDegrees;
  final double? rightKneeFlexionDegrees;
  final double? kneeFlexionAsymmetryDegrees;
  final double? deepestHipDepthRatio;
  final double? torsoInclinationAtDeepestDegrees;

  bool? get reachedHipAtOrBelowKneeHeight {
    final depth = deepestHipDepthRatio;
    if (depth == null) {
      return null;
    }
    return depth <= 0.0;
  }
}

final class BalanceAssessmentResult extends AssessmentResult {
  const BalanceAssessmentResult({
    required super.sampleCount,
    required super.hasSufficientData,
    required this.side,
    required this.rejectedSampleCount,
    required this.observedDuration,
    required this.shoulderSwayStandardDeviation,
    required this.hipSwayStandardDeviation,
    required this.averageSwayStandardDeviation,
    required this.stabilityScore,
  }) : super(type: AssessmentType.balance);

  final AssessmentSide side;
  final int rejectedSampleCount;
  final Duration observedDuration;
  final double? shoulderSwayStandardDeviation;
  final double? hipSwayStandardDeviation;
  final double? averageSwayStandardDeviation;
  final double? stabilityScore;
}

final class ShoulderMobilityAssessmentResult extends AssessmentResult {
  const ShoulderMobilityAssessmentResult({
    required super.sampleCount,
    required super.hasSufficientData,
    required this.leftMaximumElevationDegrees,
    required this.rightMaximumElevationDegrees,
    required this.sideDifferenceDegrees,
    required this.torsoInclinationAtLeftMaximumDegrees,
    required this.torsoInclinationAtRightMaximumDegrees,
  }) : super(type: AssessmentType.shoulderMobility);

  final double? leftMaximumElevationDegrees;
  final double? rightMaximumElevationDegrees;
  final double? sideDifferenceDegrees;
  final double? torsoInclinationAtLeftMaximumDegrees;
  final double? torsoInclinationAtRightMaximumDegrees;
}

class AssessmentSnapshot {
  const AssessmentSnapshot({
    required this.type,
    required this.phase,
    required this.sampleCount,
    required this.isReadyToComplete,
    required this.readinessProgress,
    required this.result,
    this.continuousEvidenceDuration,
  });

  final AssessmentType type;
  final AssessmentPhase phase;
  final int sampleCount;

  /// Whether the current evidence satisfies the product-level completion gate.
  /// This is a capture-readiness signal, not a clinical validity claim.
  final bool isReadyToComplete;

  /// Normalized 0-1 progress toward the current assessment evidence gate.
  final double readinessProgress;

  /// Continuous accepted evidence duration when the assessment has a temporal
  /// requirement, such as single-leg balance. Null for non-temporal modes.
  final Duration? continuousEvidenceDuration;

  final AssessmentResult? result;

  bool get isActive => phase == AssessmentPhase.active;
  bool get isCompleted => phase == AssessmentPhase.completed;
}
