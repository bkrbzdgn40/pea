/// Hold-specific diagnostics used while the hold engine family is still
/// maturing behind the shared analysis contract.
class HoldDiagnosticsSnapshot {
  const HoldDiagnosticsSnapshot({
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.isHolding = false,
    this.hadFormBreak = false,
    this.bodyLineTargetAngle = 0.0,
  });

  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final bool isHolding;
  final bool hadFormBreak;
  final double bodyLineTargetAngle;
}

enum HoldVisibilityResumeDisposition { resumed, ended, noGap }

class HoldVisibilityResumeResult {
  const HoldVisibilityResumeResult({required this.disposition});

  final HoldVisibilityResumeDisposition disposition;
}

/// Optional diagnostics surface for hold-style engines.
abstract class HoldDiagnostics {
  HoldDiagnosticsSnapshot get diagnosticsSnapshot;
}

/// Optional visibility-gap control surface for hold-style engines.
abstract class HoldVisibilityGapControl {
  void beginVisibilityGap();

  HoldVisibilityResumeResult resumeAfterVisibilityGap();
}
