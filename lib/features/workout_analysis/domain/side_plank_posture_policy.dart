import 'dart:math' as math;

import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'hold_posture_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

/// Side-plank validity adds a physical support-stacking gate to the legacy
/// body-line, elbow-angle, and leg-extension checks.
///
/// The selected support elbow must be below its shoulder and the
/// shoulder-to-elbow segment must be at least as vertical as it is horizontal.
/// This broad 45-degree cone encodes "elbow under shoulder" without tuning to
/// one user or one video.
class SidePlankPosturePolicy implements HoldFormPolicy {
  SidePlankPosturePolicy({required HoldPostureConfig config})
    : _basePolicy = HoldPosturePolicy(config: config);

  static final double minSupportStackingVerticalComponent = 1 / math.sqrt(2);

  final HoldPosturePolicy _basePolicy;

  @override
  Duration get breakGraceDuration => _basePolicy.breakGraceDuration;

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
    final supportStacking = signals.valueFor(HoldSignal.supportStacking);
    final isSupportStacked =
        supportStacking != null &&
        supportStacking.isFinite &&
        supportStacking >= minSupportStackingVerticalComponent;
    final hasCompleteMetrics =
        base.hasCompleteMetrics && supportStacking != null;
    final isValidHoldPosture = base.isValidHoldPosture && isSupportStacked;

    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        ...base.postureDiagnostics.signalValidity.asMap(),
        HoldSignal.supportStacking: isSupportStacked,
      },
    );

    return HoldFormEvaluation(
      hasActivePosture: base.hasActivePosture,
      hasCompleteMetrics: hasCompleteMetrics,
      targetSignalValues: targetSignalValues(isHolding: isHolding),
      postureDiagnostics: HoldPostureDiagnosticsSnapshot(
        hasActivePosture: base.hasActivePosture,
        hasCompleteMetrics: hasCompleteMetrics,
        signalValidity: signalValidity,
      ),
      correctiveFeedbackCode: isSupportStacked
          ? base.correctiveFeedbackCode
          : HoldFeedbackCode.adjustElbowSupport,
      holdValidity: isValidHoldPosture
          ? HoldValidityStatus.valid
          : HoldValidityStatus.invalid,
      breakDisposition: isSupportStacked
          ? base.breakDisposition
          : HoldBreakDisposition.breakImmediately,
    );
  }
}
