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
        // Compression remains a setup/hold reference, not a technique-quality
        // score. Entry keeps the existing active-posture gate while an active
        // hold uses the sustain target to decide validity and grace behavior.
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

    // R35 keeps variation-owned setup/validation while preserving the legacy
    // Hollow Hold hysteresis contract. Before a hold starts, active-posture
    // membership gates entry and the stricter entry target remains diagnostic.
    // Once holding, the sustain target controls continued validity; compression
    // drift alone is grace-eligible. None of this turns compression into a
    // "smaller is better" technique score.
    final isCompressionValidForState =
        isHolding ? isCompressionWithinReference : hasActivePosture;
    final isValidHoldPosture =
        hasCompleteMetrics &&
        isCompressionValidForState &&
        requiredArmValid &&
        requiredKneeValid;
    final supportsGraceWindow =
        isHolding &&
        hasCompleteMetrics &&
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
