import 'models/rep_score_breakdown.dart';

/// Range-rep specific diagnostics used by today's calibration/debug surface.
class RangeRepDiagnosticsSnapshot {
  const RangeRepDiagnosticsSnapshot({
    this.currentRepWorstBackAngle = 0.0,
    this.currentRepHadFormViolation = false,
    this.lastRepScoreBreakdown,
  });

  final double currentRepWorstBackAngle;
  final bool currentRepHadFormViolation;
  final RepScoreBreakdown? lastRepScoreBreakdown;
}

/// Optional diagnostics surface for range-rep style engines.
abstract class RangeRepDiagnostics {
  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot;
}
