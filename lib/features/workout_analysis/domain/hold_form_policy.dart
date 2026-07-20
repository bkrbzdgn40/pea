import 'hold_diagnostics.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_values.dart';

/// Hold validity is intentionally distinct from technique severity and pose
/// acceptance. It answers only whether the current engine may continue holding.
enum HoldValidityStatus { valid, invalid }

/// Explicit hold-break disposition. Technique observations do not implicitly
/// choose one of these values.
enum HoldBreakDisposition { continueHold, graceEligible, breakImmediately }

abstract interface class HoldFormPolicy {
  Duration get breakGraceDuration;

  HoldSignalValues targetSignalValues({required bool isHolding});

  HoldFormEvaluation evaluate(
    HoldSignalValues signals, {
    required bool isHolding,
  });
}

class HoldFormEvaluation {
  HoldFormEvaluation({
    required this.hasActivePosture,
    required this.hasCompleteMetrics,
    required this.targetSignalValues,
    required this.postureDiagnostics,
    required this.correctiveFeedbackCode,
    required this.holdValidity,
    required this.breakDisposition,
  });

  final bool hasActivePosture;
  final bool hasCompleteMetrics;
  final HoldSignalValues targetSignalValues;
  final HoldPostureDiagnosticsSnapshot postureDiagnostics;

  /// User-feedback decision remains explicit and separate from validity.
  final HoldFeedbackCode correctiveFeedbackCode;
  final HoldValidityStatus holdValidity;
  final HoldBreakDisposition breakDisposition;

  bool get isValidHoldPosture => holdValidity == HoldValidityStatus.valid;

  bool get supportsGraceWindow =>
      breakDisposition == HoldBreakDisposition.graceEligible;
}
