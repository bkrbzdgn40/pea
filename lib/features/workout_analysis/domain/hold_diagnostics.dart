import 'models/hold_feedback_code.dart';
import 'models/hold_phase.dart';
import 'models/hold_contract.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

const Duration holdVisibilityGapGraceDuration = Duration(milliseconds: 1200);

class HoldPostureDiagnosticsSnapshot {
  HoldPostureDiagnosticsSnapshot({
    this.hasCompleteMetrics = false,
    this.hasActivePosture = false,
    HoldSignalValidity? signalValidity,
  }) : signalValidity = signalValidity ?? const HoldSignalValidity.empty();

  final bool hasCompleteMetrics;
  final bool hasActivePosture;
  final HoldSignalValidity signalValidity;

  bool? validityFor(HoldSignal signal) => signalValidity.validityFor(signal);

  bool get isBodyAligned => validityFor(HoldSignal.alignment) ?? false;

  bool get isArmSupported => validityFor(HoldSignal.support) ?? false;

  bool get areLegsExtended => validityFor(HoldSignal.extension) ?? false;
}

/// Hold-specific diagnostics used while the hold engine family is still
/// maturing behind the shared analysis contract.
class HoldDiagnosticsSnapshot {
  HoldDiagnosticsSnapshot({
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.isHolding = false,
    this.isVisibilitySuspended = false,
    this.hadFormBreak = false,
    this.phase = HoldPhase.ready,
    this.feedbackCode = HoldFeedbackCode.preparePosition,
    HoldSignalValues? targetSignalValues,
    HoldPostureDiagnosticsSnapshot? lastVisiblePosture,
    this.isFormBreakGraceActive = false,
    this.currentStabilityScore,
    this.lastCompletedStabilityScore,
    this.sessionStabilityScore,
  }) : targetSignalValues =
           targetSignalValues ?? const HoldSignalValues.empty(),
       lastVisiblePosture =
           lastVisiblePosture ?? HoldPostureDiagnosticsSnapshot();

  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final bool isHolding;
  final bool isVisibilitySuspended;
  final bool hadFormBreak;
  final HoldPhase phase;
  final HoldFeedbackCode feedbackCode;
  final HoldSignalValues targetSignalValues;
  final HoldPostureDiagnosticsSnapshot lastVisiblePosture;
  final bool isFormBreakGraceActive;

  /// Stability is unmeasured until enough valid hold samples exist.
  final double? currentStabilityScore;
  final double? lastCompletedStabilityScore;
  final double? sessionStabilityScore;

  HoldSignalValidity get signalValidity => lastVisiblePosture.signalValidity;

  double get bodyLineTargetAngle =>
      targetSignalValues.valueFor(HoldSignal.alignment) ?? 0.0;
}

enum HoldVisibilityResumeDisposition { resumed, ended, noGap }

class HoldVisibilityResumeResult {
  const HoldVisibilityResumeResult({
    required this.disposition,
    this.gapDuration = Duration.zero,
  });

  final HoldVisibilityResumeDisposition disposition;
  final Duration gapDuration;
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
