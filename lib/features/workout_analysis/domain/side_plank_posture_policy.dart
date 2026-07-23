import 'dart:math' as math;

import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'hold_posture_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

/// Side-plank validity supports the two common stable support modes:
///
/// - forearm support, using the configured elbow-angle window;
/// - straight-arm / hand support, using a near-extension elbow angle.
///
/// Both modes still require the selected support arm to sit below the shoulder
/// through [HoldSignal.supportStacking]. The straight-arm entry boundary is
/// derived from the configured forearm upper bound and anatomical full
/// extension (180 degrees), rather than calibrated to one user or video.
class SidePlankPosturePolicy implements HoldFormPolicy {
  SidePlankPosturePolicy({required HoldPostureConfig config})
    : _config = config,
      _basePolicy = HoldPosturePolicy(config: config);

  static final double minSupportStackingVerticalComponent = 1 / math.sqrt(2);

  final HoldPostureConfig _config;
  final HoldPosturePolicy _basePolicy;

  @override
  Duration get breakGraceDuration => _basePolicy.breakGraceDuration;

  double get _straightArmSupportMinAngle =>
      (_config.armSupportMaxAngle + 180.0) / 2;

  @override
  HoldSignalValues targetSignalValues({required bool isHolding}) {
    return _basePolicy.targetSignalValues(isHolding: isHolding).mergedWith(
      <HoldSignal, double?>{
        HoldSignal.supportStacking: minSupportStackingVerticalComponent,
      },
    );
  }

  @override
  HoldFormEvaluation evaluate(
    HoldSignalValues signals, {
    required bool isHolding,
  }) {
    final base = _basePolicy.evaluate(signals, isHolding: isHolding);
    final supportAngle = signals.valueFor(HoldSignal.support);
    final supportStacking = signals.valueFor(HoldSignal.supportStacking);

    final isForearmSupport =
        supportAngle != null &&
        supportAngle.isFinite &&
        supportAngle >= _config.armSupportMinAngle &&
        supportAngle <= _config.armSupportMaxAngle;
    final isStraightArmSupport =
        supportAngle != null &&
        supportAngle.isFinite &&
        supportAngle >= _straightArmSupportMinAngle;
    final isSupportAngleValid = isForearmSupport || isStraightArmSupport;
    final isSupportStacked =
        supportStacking != null &&
        supportStacking.isFinite &&
        supportStacking >= minSupportStackingVerticalComponent;

    final baseValidity = base.postureDiagnostics.signalValidity;
    final isBodyAligned =
        baseValidity.validityFor(HoldSignal.alignment) ?? false;
    final areLegsExtended =
        baseValidity.validityFor(HoldSignal.extension) ?? false;
    final hasCompleteMetrics =
        base.hasCompleteMetrics && supportStacking != null;
    final isValidHoldPosture =
        hasCompleteMetrics &&
        isBodyAligned &&
        isSupportAngleValid &&
        isSupportStacked &&
        areLegsExtended;
    final supportsGraceWindow =
        hasCompleteMetrics &&
        !isBodyAligned &&
        isSupportAngleValid &&
        isSupportStacked &&
        areLegsExtended;

    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        ...baseValidity.asMap(),
        HoldSignal.support: isSupportAngleValid,
        HoldSignal.supportStacking: isSupportStacked,
      },
    );

    final correctiveFeedbackCode = !isSupportStacked
        ? HoldFeedbackCode.placeSupportElbowUnderShoulder
        : (!isSupportAngleValid
              ? HoldFeedbackCode.useForearmSupport
              : (!isBodyAligned
                    ? HoldFeedbackCode.alignHips
                    : (!areLegsExtended
                          ? HoldFeedbackCode.extendLegs
                          : HoldFeedbackCode.correctForm)));

    return HoldFormEvaluation(
      hasActivePosture: base.hasActivePosture,
      hasCompleteMetrics: hasCompleteMetrics,
      targetSignalValues: targetSignalValues(isHolding: isHolding),
      postureDiagnostics: HoldPostureDiagnosticsSnapshot(
        hasActivePosture: base.hasActivePosture,
        hasCompleteMetrics: hasCompleteMetrics,
        signalValidity: signalValidity,
      ),
      correctiveFeedbackCode: correctiveFeedbackCode,
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
}
