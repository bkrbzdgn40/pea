import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';
import 'models/hollow_hold_variation.dart';

const double _armExtensionMeasurementToleranceDegrees = 15.0;

class HollowHoldPosturePolicy implements HoldFormPolicy {
  const HollowHoldPosturePolicy({
    required this.config,
    this.variationContract = HollowHoldVariationContracts.straightLegOverhead,
  });

  final HollowHoldPostureConfig config;
  final HollowHoldVariationContract variationContract;

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
        // Compression remains a detection/setup reference, not a technique
        // quality score. It is retained here for diagnostics and entry UX.
        HoldSignal.compression: compressionTargetAngle(isHolding: isHolding),
        if (variationContract.requiresArmsOverhead)
          HoldSignal.armExtension: config.armExtensionMinAngle,
        if (variationContract.requiresStraightKnees)
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

    final hasActivePosture =
        compressionAngle != null &&
        compressionAngle <= config.activePostureMaxAngle;
    final isCompressionWithinReference =
        compressionAngle != null &&
        compressionAngle <= compressionTargetAngle(isHolding: isHolding);
    final isArmExtensionValid =
        armExtensionAngle != null &&
        armExtensionAngle >= armExtensionAcceptanceMinAngle;
    final isKneeExtensionValid =
        kneeExtensionAngle != null &&
        kneeExtensionAngle >= config.kneeExtensionMinAngle;

    final hasCompleteMetrics =
        compressionAngle != null &&
        (!variationContract.requiresArmsOverhead ||
            armExtensionAngle != null) &&
        (!variationContract.requiresStraightKnees ||
            kneeExtensionAngle != null);
    final requiredArmValid =
        !variationContract.requiresArmsOverhead || isArmExtensionValid;
    final requiredKneeValid =
        !variationContract.requiresStraightKnees || isKneeExtensionValid;

    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        HoldSignal.compression: isCompressionWithinReference,
        if (variationContract.requiresArmsOverhead)
          HoldSignal.armExtension: isArmExtensionValid,
        if (variationContract.requiresStraightKnees)
          HoldSignal.kneeExtension: isKneeExtensionValid,
      },
    );

    // R35: setup/validation is variation-owned. Compression remains a
    // setup/hold-validity reference with the existing grace window, but it is
    // not treated as a "smaller is better" technique-quality score.
    final isValidHoldPosture =
        hasCompleteMetrics &&
        hasActivePosture &&
        isCompressionWithinReference &&
        requiredArmValid &&
        requiredKneeValid;
    final supportsGraceWindow =
        hasCompleteMetrics &&
        hasActivePosture &&
        !isCompressionWithinReference &&
        requiredArmValid &&
        requiredKneeValid;

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
        isCompressionWithinReference: isCompressionWithinReference,
        isArmExtensionValid: isArmExtensionValid,
        isKneeExtensionValid: isKneeExtensionValid,
      ),
      holdValidity: isValidHoldPosture
          ? HoldValidityStatus.valid
          : HoldValidityStatus.invalid,
      breakDisposition: isValidHoldPosture
          ? HoldBreakDisposition.continueHold
          : (supportsGraceWindow
                ? HoldBreakDisposition.graceEligible
                : HoldBreakDisposition.breakImmediately),
    );
  }

  HoldFeedbackCode _resolveCorrectiveFeedbackCode({
    required bool isCompressionWithinReference,
    required bool isArmExtensionValid,
    required bool isKneeExtensionValid,
  }) {
    if (!isCompressionWithinReference) {
      return HoldFeedbackCode.increaseHollowCompression;
    }
    if (variationContract.requiresArmsOverhead && !isArmExtensionValid) {
      return HoldFeedbackCode.extendArmsOverhead;
    }
    if (variationContract.requiresStraightKnees && !isKneeExtensionValid) {
      return HoldFeedbackCode.straightenKnees;
    }
    return HoldFeedbackCode.correctForm;
  }
}
