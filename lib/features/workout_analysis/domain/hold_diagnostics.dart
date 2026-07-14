import 'models/hold_feedback_code.dart';
import 'models/hold_phase.dart';

class HoldPostureDiagnosticsSnapshot {
  const HoldPostureDiagnosticsSnapshot({
    this.hasCompleteMetrics = false,
    this.hasActivePosture = false,
    this.isBodyAligned = false,
    this.isArmSupported = false,
    this.areLegsExtended = false,
  });

  final bool hasCompleteMetrics;
  final bool hasActivePosture;
  final bool isBodyAligned;
  final bool isArmSupported;
  final bool areLegsExtended;
}

/// Hold-specific diagnostics used while the hold engine family is still
/// maturing behind the shared analysis contract.
class HoldDiagnosticsSnapshot {
  const HoldDiagnosticsSnapshot({
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.isHolding = false,
    this.isVisibilitySuspended = false,
    this.hadFormBreak = false,
    this.bodyLineTargetAngle = 0.0,
    this.phase = HoldPhase.ready,
    this.feedbackCode = HoldFeedbackCode.preparePosition,
    this.lastVisiblePosture = const HoldPostureDiagnosticsSnapshot(),
    this.isFormBreakGraceActive = false,
  });

  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final bool isHolding;
  final bool isVisibilitySuspended;
  final bool hadFormBreak;
  final double bodyLineTargetAngle;
  final HoldPhase phase;
  final HoldFeedbackCode feedbackCode;
  final HoldPostureDiagnosticsSnapshot lastVisiblePosture;
  final bool isFormBreakGraceActive;
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

/// Optional interruption control surface for hold-style engines.
abstract class HoldInterruptionControl {
  void endActiveHoldForInterruption();
}
