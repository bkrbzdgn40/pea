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

/// Optional diagnostics surface for hold-style engines.
abstract class HoldDiagnostics {
  HoldDiagnosticsSnapshot get diagnosticsSnapshot;
}
