import 'models/rep_score_breakdown.dart';

const String rangeRepAwaitNeutralPhaseLabel = 'AWAITING_NEUTRAL';
const String rangeRepAwaitNeutralPendingTransitionLabel = 'await neutral';
const Duration rangeRepVisibilityGapGraceDuration = Duration(
  milliseconds: 1500,
);

class RangeRepPhaseQualitySnapshot {
  const RangeRepPhaseQualitySnapshot({
    this.hasData = false,
    this.durationMs = 0,
    this.minPrimaryMetric,
    this.maxPrimaryMetric,
    this.worstFormMetric,
    this.hadFormViolation = false,
  });

  final bool hasData;
  final int durationMs;
  final double? minPrimaryMetric;
  final double? maxPrimaryMetric;
  final double? worstFormMetric;
  final bool hadFormViolation;
}

class RangeRepPhaseQualityTelemetry {
  const RangeRepPhaseQualityTelemetry({
    this.descendingPhaseQuality = const RangeRepPhaseQualitySnapshot(),
    this.peakPhaseQuality = const RangeRepPhaseQualitySnapshot(),
    this.ascendingPhaseQuality = const RangeRepPhaseQualitySnapshot(),
  });

  final RangeRepPhaseQualitySnapshot descendingPhaseQuality;
  final RangeRepPhaseQualitySnapshot peakPhaseQuality;
  final RangeRepPhaseQualitySnapshot ascendingPhaseQuality;
}

enum RangeRepPhaseQualityStatus { unavailable, observed, flagged }

extension RangeRepPhaseQualityStatusX on RangeRepPhaseQualityStatus {
  String get debugLabel {
    switch (this) {
      case RangeRepPhaseQualityStatus.unavailable:
        return 'unavailable';
      case RangeRepPhaseQualityStatus.observed:
        return 'observed';
      case RangeRepPhaseQualityStatus.flagged:
        return 'flagged';
    }
  }
}

enum RangeRepPhaseQualityIssue { durationTooShort, formViolation }

extension RangeRepPhaseQualityIssueX on RangeRepPhaseQualityIssue {
  String get debugLabel {
    switch (this) {
      case RangeRepPhaseQualityIssue.durationTooShort:
        return 'duration too short';
      case RangeRepPhaseQualityIssue.formViolation:
        return 'form violation';
    }
  }
}

class RangeRepPhaseQualityAssessment {
  const RangeRepPhaseQualityAssessment({
    this.status = RangeRepPhaseQualityStatus.unavailable,
    this.issues = const <RangeRepPhaseQualityIssue>[],
  });

  final RangeRepPhaseQualityStatus status;
  final List<RangeRepPhaseQualityIssue> issues;
}

/// Technique-enriched facts about a fully completed range-rep repetition.
class RangeRepCompletedRepCoreData {
  const RangeRepCompletedRepCoreData({
    required this.repIndex,
    required this.minAngle,
    required this.worstFormMetric,
    required this.descentDuration,
    required this.ascentDuration,
    required this.hadFormViolation,
    required this.completedPhaseSequence,
  });

  final int repIndex;
  final double minAngle;
  final double worstFormMetric;
  final Duration descentDuration;
  final Duration ascentDuration;
  final bool hadFormViolation;
  final bool completedPhaseSequence;
}

/// Range-rep specific diagnostics used by today's calibration/debug surface.
class RangeRepDiagnosticsSnapshot {
  const RangeRepDiagnosticsSnapshot({
    this.currentRepWorstBackAngle = 0.0,
    this.currentRepHadFormViolation = false,
    this.phaseGateStatus = 'stable',
    this.hasActiveRepPhase = false,
    this.hasPendingTransition = false,
    this.pendingTransitionLabel,
    this.lastConfirmedTransitionLabel,
    this.lastRepScoreBreakdown,
    this.lastCompletedRepCoreData,
    this.descendingPhaseQuality = const RangeRepPhaseQualitySnapshot(),
    this.peakPhaseQuality = const RangeRepPhaseQualitySnapshot(),
    this.ascendingPhaseQuality = const RangeRepPhaseQualitySnapshot(),
    this.descendingPhaseAssessment = const RangeRepPhaseQualityAssessment(),
    this.peakPhaseAssessment = const RangeRepPhaseQualityAssessment(),
    this.ascendingPhaseAssessment = const RangeRepPhaseQualityAssessment(),
    this.phaseFeedbackCandidate,
  });

  final double currentRepWorstBackAngle;
  final bool currentRepHadFormViolation;
  final String phaseGateStatus;
  final bool hasActiveRepPhase;
  final bool hasPendingTransition;
  final String? pendingTransitionLabel;
  final String? lastConfirmedTransitionLabel;
  final RepScoreBreakdown? lastRepScoreBreakdown;
  final RangeRepCompletedRepCoreData? lastCompletedRepCoreData;
  final RangeRepPhaseQualitySnapshot descendingPhaseQuality;
  final RangeRepPhaseQualitySnapshot peakPhaseQuality;
  final RangeRepPhaseQualitySnapshot ascendingPhaseQuality;
  final RangeRepPhaseQualityAssessment descendingPhaseAssessment;
  final RangeRepPhaseQualityAssessment peakPhaseAssessment;
  final RangeRepPhaseQualityAssessment ascendingPhaseAssessment;
  final String? phaseFeedbackCandidate;
}

/// Optional diagnostics surface for range-rep style engines.
abstract class RangeRepDiagnostics {
  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot;
}

/// Detection-only diagnostics consumed by the production coordinator.
abstract class RangeRepDetectionDiagnostics {
  RangeRepDiagnosticsSnapshot get detectionDiagnosticsSnapshot;
}

/// Optional explicit seam for consuming newly completed rep core facts exactly
/// once from a range-rep engine.
abstract class RangeRepValidationHook {
  RangeRepCompletedRepCoreData? consumeCompletedRepCoreData();
}

/// Optional recovery surface for range-rep engines that can discard only the
/// active repetition context while preserving session-level history.
abstract class RangeRepResyncControl {
  void clearActiveRepContext({String? reason});
}

enum VisibilityGapResumeDisposition { compatible, incompatible, noGap }

class VisibilityGapResumeResult {
  const VisibilityGapResumeResult({
    required this.disposition,
    this.reason,
    this.appliedGapDuration = Duration.zero,
  });

  final VisibilityGapResumeDisposition disposition;
  final String? reason;
  final Duration appliedGapDuration;

  bool get isCompatible =>
      disposition == VisibilityGapResumeDisposition.compatible ||
      disposition == VisibilityGapResumeDisposition.noGap;
}

abstract class RangeRepVisibilityGapControl {
  void beginBriefVisibilityGap();

  VisibilityGapResumeResult resumeAfterBriefVisibilityGap({
    required double primaryMetric,
  });
}

extension RangeRepDiagnosticsSnapshotX on RangeRepDiagnosticsSnapshot {
  bool get hasRepContext =>
      hasActiveRepPhase ||
      (hasPendingTransition &&
          pendingTransitionLabel != rangeRepAwaitNeutralPendingTransitionLabel);

  bool get isAwaitingNeutralConfirmation =>
      hasPendingTransition &&
      pendingTransitionLabel == rangeRepAwaitNeutralPendingTransitionLabel;
}
