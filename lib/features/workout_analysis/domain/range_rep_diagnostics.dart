import 'models/rep_score_breakdown.dart';

/// Range-rep specific diagnostics used by today's calibration/debug surface.
class RangeRepDiagnosticsSnapshot {
  const RangeRepDiagnosticsSnapshot({
    this.currentRepWorstBackAngle = 0.0,
    this.currentRepHadFormViolation = false,
    this.phaseGateStatus = 'stable',
    this.pendingTransitionLabel,
    this.lastConfirmedTransitionLabel,
    this.lastRepScoreBreakdown,
  });

  final double currentRepWorstBackAngle;
  final bool currentRepHadFormViolation;
  final String phaseGateStatus;
  final String? pendingTransitionLabel;
  final String? lastConfirmedTransitionLabel;
  final RepScoreBreakdown? lastRepScoreBreakdown;
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
