import 'hold_diagnostics.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_contract.dart';
import 'models/hold_signal_values.dart';

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
    required this.isValidHoldPosture,
    required this.supportsGraceWindow,
  });

  final bool hasActivePosture;
  final bool hasCompleteMetrics;
  final HoldSignalValues targetSignalValues;
  final HoldPostureDiagnosticsSnapshot postureDiagnostics;
  final HoldFeedbackCode correctiveFeedbackCode;
  final bool isValidHoldPosture;
  final bool supportsGraceWindow;

  double get bodyLineTargetAngle =>
      targetSignalValues.valueFor(HoldSignal.alignment) ?? 0.0;

  bool get isBodyAligned => postureDiagnostics.isBodyAligned;

  bool get isArmSupported => postureDiagnostics.isArmSupported;

  bool get areLegsExtended => postureDiagnostics.areLegsExtended;
}
