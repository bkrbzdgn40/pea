import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

const double _armExtensionMeasurementToleranceDegrees = 15.0;

class HollowHoldPosturePolicy implements HoldFormPolicy {
  const HollowHoldPosturePolicy({required this.config});

  final HollowHoldPostureConfig config;

  @override
  Duration get breakGraceDuration => config.breakGraceDuration;

  double compressionTargetAngle({required bool isHolding}) {
    return isHolding
        ? config.compressionSustainMaxAngle
        : config.compressionEntryMaxAngle;
  }

  double get armExtensionAcceptanceMinAngle =>
      config.armExtensionMinAngle - _armExtensionMeasurementToleranceDegrees;

  @override
  HoldSignalValues targetSignalValues({required bool isHolding}) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.compression: compressionTargetAngle(isHolding: isHolding),
        HoldSignal.armExtension: config.armExtensionMinAngle,
        HoldSignal.kneeExtension: config.kneeExtensionMinAngle,
      },
    );
  }

  @override
  HoldFormEvaluation evaluate(
    HoldSignalValues signals, {
    required bool isHolding,
  }) {
    final compressionAngle = signals.valueFor(HoldSignal.compression);
    final armExtensionAngle = signals.valueFor(HoldSignal.armExtension);
    final kneeExtensionAngle = signals.valueFor(HoldSignal.kneeExtension);
    final targetCompressionAngle = compressionTargetAngle(isHolding: isHolding);
    final hasCompleteMetrics =
        compressionAngle != null &&
        armExtensionAngle != null &&
        kneeExtensionAngle != null;
    final hasActivePosture =
        compressionAngle != null &&
        compressionAngle <= config.activePostureMaxAngle;
    final isCompressionValid =
        hasCompleteMetrics && compressionAngle <= targetCompressionAngle;
    final isArmExtensionValid =
        hasCompleteMetrics &&
        armExtensionAngle >= armExtensionAcceptanceMinAngle;
    final isKneeExtensionValid =
        hasCompleteMetrics &&
        kneeExtensionAngle >= config.kneeExtensionMinAngle;
    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        HoldSignal.compression: isCompressionValid,
        HoldSignal.armExtension: isArmExtensionValid,
        HoldSignal.kneeExtension: isKneeExtensionValid,
      },
    );
    final isValidHoldPosture =
        hasCompleteMetrics &&
        isCompressionValid &&
        isArmExtensionValid &&
        isKneeExtensionValid;
    final supportsGraceWindow =
        hasCompleteMetrics &&
        !isCompressionValid &&
        isArmExtensionValid &&
        isKneeExtensionValid;

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
        isCompressionValid: isCompressionValid,
        isArmExtensionValid: isArmExtensionValid,
        isKneeExtensionValid: isKneeExtensionValid,
      ),
      isValidHoldPosture: isValidHoldPosture,
      supportsGraceWindow: supportsGraceWindow,
    );
  }

  HoldFeedbackCode _resolveCorrectiveFeedbackCode({
    required bool isCompressionValid,
    required bool isArmExtensionValid,
    required bool isKneeExtensionValid,
  }) {
    if (!isCompressionValid) {
      return HoldFeedbackCode.increaseHollowCompression;
    }
    if (!isArmExtensionValid) {
      return HoldFeedbackCode.extendArmsOverhead;
    }
    if (!isKneeExtensionValid) {
      return HoldFeedbackCode.straightenKnees;
    }
    return HoldFeedbackCode.correctForm;
  }
}
