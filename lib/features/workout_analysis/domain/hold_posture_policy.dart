import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

class HoldPosturePolicy implements HoldFormPolicy {
  const HoldPosturePolicy({required this.config});

  final HoldPostureConfig config;

  @override
  Duration get breakGraceDuration => config.breakGraceDuration;

  double bodyLineTargetAngle({required bool isHolding}) {
    return isHolding ? config.bodyLineSustainAngle : config.bodyLineEntryAngle;
  }

  @override
  HoldSignalValues targetSignalValues({required bool isHolding}) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.alignment: bodyLineTargetAngle(isHolding: isHolding),
      },
    );
  }

  @override
  HoldFormEvaluation evaluate(
    HoldSignalValues signals, {
    required bool isHolding,
  }) {
    final bodyLineAngle = signals.valueFor(HoldSignal.alignment);
    final armSupportAngle = signals.valueFor(HoldSignal.support);
    final legExtensionAngle = signals.valueFor(HoldSignal.extension);
    final targetAngle = bodyLineTargetAngle(isHolding: isHolding);
    final hasCompleteMetrics =
        bodyLineAngle != null &&
        armSupportAngle != null &&
        legExtensionAngle != null;
    final hasActivePosture =
        bodyLineAngle != null && bodyLineAngle >= config.activePostureAngle;
    final isBodyAligned = hasCompleteMetrics && bodyLineAngle >= targetAngle;
    final isArmSupported =
        hasCompleteMetrics &&
        armSupportAngle >= config.armSupportMinAngle &&
        armSupportAngle <= config.armSupportMaxAngle;
    final areLegsExtended =
        hasCompleteMetrics && legExtensionAngle >= config.legExtensionMinAngle;
    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        HoldSignal.alignment: isBodyAligned,
        HoldSignal.support: isArmSupported,
        HoldSignal.extension: areLegsExtended,
      },
    );
    final isValidHoldPosture =
        hasCompleteMetrics &&
        isBodyAligned &&
        isArmSupported &&
        areLegsExtended;
    final supportsGraceWindow =
        hasCompleteMetrics &&
        !isBodyAligned &&
        isArmSupported &&
        areLegsExtended;

    return HoldFormEvaluation(
      hasActivePosture: hasActivePosture,
      hasCompleteMetrics: hasCompleteMetrics,
      targetSignalValues: targetSignalValues(isHolding: isHolding),
      postureDiagnostics: HoldPostureDiagnosticsSnapshot(
        hasActivePosture: hasActivePosture,
        hasCompleteMetrics: hasCompleteMetrics,
        signalValidity: signalValidity,
      ),
      correctiveFeedbackCode: _resolveCorrectiveFeedbackCode(
        isBodyAligned: isBodyAligned,
        isArmSupported: isArmSupported,
        areLegsExtended: areLegsExtended,
      ),
      isValidHoldPosture: isValidHoldPosture,
      supportsGraceWindow: supportsGraceWindow,
    );
  }

  HoldFeedbackCode _resolveCorrectiveFeedbackCode({
    required bool isBodyAligned,
    required bool isArmSupported,
    required bool areLegsExtended,
  }) {
    if (!isBodyAligned) {
      return HoldFeedbackCode.alignHips;
    }
    if (!isArmSupported) {
      return HoldFeedbackCode.adjustElbowSupport;
    }
    if (!areLegsExtended) {
      return HoldFeedbackCode.extendLegs;
    }
    return HoldFeedbackCode.correctForm;
  }
}
