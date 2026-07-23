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

  HoldSignalValues signals({required double supportStacking}) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.alignment: 170,
        HoldSignal.support: 90,
        HoldSignal.supportStacking: supportStacking,
        HoldSignal.extension: 170,
      },
    );
  }

  test('accepts a support elbow that is vertically below the shoulder', () {
    final evaluation = policy.evaluate(
      signals(supportStacking: 0.95),
      isHolding: false,
    );

    expect(evaluation.isValidHoldPosture, isTrue);
    expect(
      evaluation.postureDiagnostics.signalValidity.validityFor(
        HoldSignal.supportStacking,
      ),
      isTrue,
    );
  });

  test('rejects a bent elbow that is above the shoulder', () {
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
      HoldFeedbackCode.adjustElbowSupport,
    );
  });

  test(
    'preserves the legacy alignment grace window when support is stacked',
    () {
      final evaluation = policy.evaluate(
        HoldSignalValues(
          values: <HoldSignal, double>{
            HoldSignal.alignment: 160,
            HoldSignal.support: 90,
            HoldSignal.supportStacking: 0.95,
            HoldSignal.extension: 170,
          },
        ),
        isHolding: true,
      );

      expect(evaluation.isValidHoldPosture, isFalse);
      expect(evaluation.supportsGraceWindow, isTrue);
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
