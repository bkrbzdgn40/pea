import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/side_plank_posture_policy.dart';

void main() {
  final policy = SidePlankPosturePolicy(
    config: const HoldPostureConfig(
      activePostureAngle: 155,
      bodyLineEntryAngle: 165,
      bodyLineSustainAngle: 162,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 160,
      breakGraceDuration: Duration(milliseconds: 350),
    ),
  );

  HoldSignalValues signals({
    required double supportStacking,
    double supportAngle = 90,
    double alignment = 170,
    double extension = 170,
  }) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.alignment: alignment,
        HoldSignal.support: supportAngle,
        HoldSignal.supportStacking: supportStacking,
        HoldSignal.extension: extension,
      },
    );
  }

  test('accepts stacked forearm support', () {
    final evaluation = policy.evaluate(
      signals(supportStacking: 0.95),
      isHolding: false,
    );

    expect(evaluation.isValidHoldPosture, isTrue);
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.support,
      ),
      isTrue,
    );
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.supportStacking,
      ),
      isTrue,
    );
  });

  test(
    'accepts stacked straight-arm support as a valid side plank variation',
    () {
      final evaluation = policy.evaluate(
        signals(supportStacking: 0.95, supportAngle: 170),
        isHolding: false,
      );

      expect(evaluation.isValidHoldPosture, isTrue);
      expect(
        evaluation.postureDiagnostics.signalValidity.validityFor(
          HoldSignal.support,
        ),
        isTrue,
      );
      expect(evaluation.correctiveFeedbackCode, HoldFeedbackCode.correctForm);
    },
  );

  test('rejects a support arm that is not stacked below the shoulder', () {
    final evaluation = policy.evaluate(
      signals(supportStacking: -0.8),
      isHolding: false,
    );

    expect(evaluation.isValidHoldPosture, isFalse);
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.support,
      ),
      isTrue,
    );
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.supportStacking,
      ),
      isFalse,
    );
    expect(evaluation.postureDiagnostics.isArmSupported, isFalse);
    expect(
      evaluation.correctiveFeedbackCode,
      HoldFeedbackCode.placeSupportElbowUnderShoulder,
    );
  });

  test('rejects ambiguous partially bent support between stable modes', () {
    final evaluation = policy.evaluate(
      signals(supportStacking: 0.95, supportAngle: 135),
      isHolding: false,
    );

    expect(evaluation.isValidHoldPosture, isFalse);
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.support,
      ),
      isFalse,
    );
    expect(
      evaluation.correctiveFeedbackCode,
      HoldFeedbackCode.useForearmSupport,
    );
  });

  test(
    'preserves the alignment grace window for either stable support mode',
    () {
      final forearm = policy.evaluate(
        signals(supportStacking: 0.95, alignment: 160),
        isHolding: true,
      );
      final straightArm = policy.evaluate(
        signals(supportStacking: 0.95, supportAngle: 170, alignment: 160),
        isHolding: true,
      );

      expect(forearm.isValidHoldPosture, isFalse);
      expect(forearm.supportsGraceWindow, isTrue);
      expect(straightArm.isValidHoldPosture, isFalse);
      expect(straightArm.supportsGraceWindow, isTrue);
    },
  );

  test('missing stacking evidence cannot start a side plank hold', () {
    final evaluation = policy.evaluate(
      HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: 170,
          HoldSignal.support: 90,
          HoldSignal.extension: 170,
        },
      ),
      isHolding: false,
    );

    expect(evaluation.hasCompleteMetrics, isFalse);
    expect(evaluation.isValidHoldPosture, isFalse);
  });
}
