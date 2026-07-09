import 'models/rep_score_breakdown.dart';

/// Core engine-owned facts about the last fully completed range-rep repetition.
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
}

/// Optional diagnostics surface for range-rep style engines.
abstract class RangeRepDiagnostics {
  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot;
}

/// Optional recovery surface for range-rep engines that can discard only the
/// active repetition context while preserving session-level history.
abstract class RangeRepResyncControl {
  void clearActiveRepContext({String? reason});
}
