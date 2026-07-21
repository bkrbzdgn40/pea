import 'feedback_arbitration_engine.dart';
import 'form_rule_engine.dart';
import 'hold_diagnostics.dart';
import 'hold_form_policy.dart';
import 'models/exercise_config.dart';
import 'models/hold_contract.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_signal_values.dart';

class WallSitPosturePolicy implements HoldFormPolicy {
  const WallSitPosturePolicy({
    required this.config,
    FormRuleEngine formRuleEngine = const FormRuleEngine(),
    FeedbackArbitrationEngine feedbackArbitrationEngine =
        const FeedbackArbitrationEngine(),
  }) : _formRuleEngine = formRuleEngine,
       _feedbackArbitrationEngine = feedbackArbitrationEngine;

  static const String _kneeRuleId = 'wall_sit_knee_depth';
  static const String _hipRuleId = 'wall_sit_hip_position';
  static const String _torsoRuleId = 'wall_sit_torso_alignment';

  final WallSitPostureConfig config;
  final FormRuleEngine _formRuleEngine;
  final FeedbackArbitrationEngine _feedbackArbitrationEngine;

  @override
  Duration get breakGraceDuration => config.breakGraceDuration;

  @override
  HoldSignalValues targetSignalValues({required bool isHolding}) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.kneeFlexion:
            (config.kneeMinAngle + config.kneeMaxAngle) / 2.0,
        HoldSignal.hipFlexion: (config.hipMinAngle + config.hipMaxAngle) / 2.0,
        HoldSignal.torsoAlignment: config.torsoMinAngle,
      },
    );
  }

  @override
  HoldFormEvaluation evaluate(
    HoldSignalValues signals, {
    required bool isHolding,
  }) {
    final kneeAngle = signals.valueFor(HoldSignal.kneeFlexion);
    final hipAngle = signals.valueFor(HoldSignal.hipFlexion);
    final torsoAngle = signals.valueFor(HoldSignal.torsoAlignment);
    final ruleContext = _WallSitRuleContext(
      kneeAngle: kneeAngle,
      hipAngle: hipAngle,
      torsoAngle: torsoAngle,
      config: config,
    );
    final ruleEvaluation = _formRuleEngine.evaluate<_WallSitRuleContext>(
      context: ruleContext,
      rules: _rules,
    );
    final violatedRuleIds = ruleEvaluation.violations
        .map((violation) => violation.ruleId)
        .toSet();

    final hasCompleteMetrics =
        kneeAngle != null && hipAngle != null && torsoAngle != null;
    final hasActivePosture =
        kneeAngle != null && kneeAngle <= config.activeKneeMaxAngle;
    final isKneeDepthValid =
        kneeAngle != null && !violatedRuleIds.contains(_kneeRuleId);
    final isHipPositionValid =
        hipAngle != null && !violatedRuleIds.contains(_hipRuleId);
    final isTorsoAligned =
        torsoAngle != null && !violatedRuleIds.contains(_torsoRuleId);

    final signalValidity = HoldSignalValidity(
      values: <HoldSignal, bool>{
        HoldSignal.kneeFlexion: isKneeDepthValid,
        HoldSignal.hipFlexion: isHipPositionValid,
        HoldSignal.torsoAlignment: isTorsoAligned,
      },
    );
    final isValidHoldPosture =
        hasCompleteMetrics &&
        isKneeDepthValid &&
        isHipPositionValid &&
        isTorsoAligned;
    final supportsGraceWindow =
        isHolding && hasCompleteMetrics && hasActivePosture;

    return HoldFormEvaluation(
      hasActivePosture: hasActivePosture,
      hasCompleteMetrics: hasCompleteMetrics,
      targetSignalValues: targetSignalValues(isHolding: isHolding),
      postureDiagnostics: HoldPostureDiagnosticsSnapshot(
        hasActivePosture: hasActivePosture,
        hasCompleteMetrics: hasCompleteMetrics,
        signalValidity: signalValidity,
      ),
      correctiveFeedbackCode: _resolveCorrectiveFeedbackCode(ruleEvaluation),
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

  static final List<FormRule<_WallSitRuleContext>> _rules =
      List<FormRule<_WallSitRuleContext>>.unmodifiable(
        <FormRule<_WallSitRuleContext>>[
          FormRule<_WallSitRuleContext>(
            id: _kneeRuleId,
            code: 'wall_sit_depth_out_of_range',
            severity: FormRuleSeverity.warning,
            valueOf: (context) => context.kneeAngle,
            minimumOf: (context) => context.config.kneeMinAngle,
            maximumOf: (context) => context.config.kneeMaxAngle,
            contextOf: (_) => 'wall_sit',
          ),
          FormRule<_WallSitRuleContext>(
            id: _hipRuleId,
            code: 'wall_sit_hip_out_of_range',
            severity: FormRuleSeverity.warning,
            valueOf: (context) => context.hipAngle,
            minimumOf: (context) => context.config.hipMinAngle,
            maximumOf: (context) => context.config.hipMaxAngle,
            contextOf: (_) => 'wall_sit',
          ),
          FormRule<_WallSitRuleContext>(
            id: _torsoRuleId,
            code: 'wall_sit_torso_alignment',
            severity: FormRuleSeverity.warning,
            valueOf: (context) => context.torsoAngle,
            minimumOf: (context) => context.config.torsoMinAngle,
            contextOf: (_) => 'wall_sit',
          ),
        ],
      );

  HoldFeedbackCode _resolveCorrectiveFeedbackCode(
    FormRuleEvaluation ruleEvaluation,
  ) {
    final decision = _feedbackArbitrationEngine.arbitrate<HoldFeedbackCode>(
      candidates: <FeedbackCandidate<HoldFeedbackCode>>[
        for (final violation in ruleEvaluation.violations)
          FeedbackCandidate<HoldFeedbackCode>(
            id: violation.ruleId,
            value: _feedbackCodeForRuleId(violation.ruleId),
            priority: FeedbackPriority.corrective,
          ),
      ],
    );

    return decision.selectedValue ?? HoldFeedbackCode.correctForm;
  }

  HoldFeedbackCode _feedbackCodeForRuleId(String ruleId) {
    if (ruleId == _kneeRuleId || ruleId == _hipRuleId) {
      return HoldFeedbackCode.adjustWallSitDepth;
    }
    if (ruleId == _torsoRuleId) {
      return HoldFeedbackCode.alignWallSitTorso;
    }
    return HoldFeedbackCode.correctForm;
  }
}

class _WallSitRuleContext {
  const _WallSitRuleContext({
    required this.kneeAngle,
    required this.hipAngle,
    required this.torsoAngle,
    required this.config,
  });

  final double? kneeAngle;
  final double? hipAngle;
  final double? torsoAngle;
  final WallSitPostureConfig config;
}
