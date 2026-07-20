import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_form_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hollow_hold_posture_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

void main() {
  const config = HollowHoldPostureConfig(
    activePostureMaxAngle: 170.0,
    compressionEntryMaxAngle: 165.0,
    compressionSustainMaxAngle: 169.0,
    armExtensionMinAngle: 135.0,
    kneeExtensionMinAngle: 165.0,
    breakGraceDuration: Duration(milliseconds: 300),
  );
  final policy = HollowHoldPosturePolicy(config: config);

  group('HollowHoldPosturePolicy', () {
    test('implements the generic hold form policy contract', () {
      expect(policy, isA<HoldFormPolicy>());
      expect(policy.breakGraceDuration, const Duration(milliseconds: 300));
      expect(policy.armExtensionAcceptanceMinAngle, 120.0);
    });

    test(
      'uses entry and sustain compression thresholds as hysteresis targets',
      () {
        final entryEvaluation = policy.evaluate(
          _signals(
            compressionAngle: 167.0,
            armExtensionAngle: 136.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: false,
        );
        final sustainEvaluation = policy.evaluate(
          _signals(
            compressionAngle: 167.0,
            armExtensionAngle: 136.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: true,
        );

        expect(
          entryEvaluation.targetSignalValues.valueFor(HoldSignal.compression),
          165.0,
        );
        expect(
          entryEvaluation.targetSignalValues.valueFor(HoldSignal.armExtension),
          135.0,
        );
        expect(
          entryEvaluation.targetSignalValues.valueFor(HoldSignal.kneeExtension),
          165.0,
        );
        expect(
          entryEvaluation.postureDiagnostics.validityFor(
            HoldSignal.compression,
          ),
          isFalse,
        );
        expect(entryEvaluation.isValidHoldPosture, isTrue);

        expect(
          sustainEvaluation.targetSignalValues.valueFor(HoldSignal.compression),
          169.0,
        );
        expect(
          sustainEvaluation.postureDiagnostics.validityFor(
            HoldSignal.compression,
          ),
          isTrue,
        );
        expect(sustainEvaluation.isValidHoldPosture, isTrue);
      },
    );

    test(
      'treats boundary values as inclusive and keeps active posture distinct from valid entry posture',
      () {
        final boundaryEvaluation = policy.evaluate(
          _signals(
            compressionAngle: 165.0,
            armExtensionAngle: 120.0,
            kneeExtensionAngle: 165.0,
          ),
          isHolding: false,
        );
        final activeButInvalidEvaluation = policy.evaluate(
          _signals(
            compressionAngle: 168.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: false,
        );

        expect(boundaryEvaluation.hasActivePosture, isTrue);
        expect(boundaryEvaluation.hasCompleteMetrics, isTrue);
        expect(boundaryEvaluation.isValidHoldPosture, isTrue);
        expect(activeButInvalidEvaluation.hasActivePosture, isTrue);
        expect(activeButInvalidEvaluation.isValidHoldPosture, isTrue);
      },
    );

    test('accepts the measured real-device correct hollow hold sample', () {
      final evaluation = policy.evaluate(
        _signals(
          compressionAngle: 164.2008483809672,
          armExtensionAngle: 126.97889758142742,
          kneeExtensionAngle: 175.183585533214,
        ),
        isHolding: false,
      );

      expect(evaluation.hasActivePosture, isTrue);
      expect(evaluation.hasCompleteMetrics, isTrue);
      expect(
        evaluation.postureDiagnostics.validityFor(HoldSignal.compression),
        isTrue,
      );
      expect(
        evaluation.postureDiagnostics.validityFor(HoldSignal.armExtension),
        isTrue,
      );
      expect(
        evaluation.postureDiagnostics.validityFor(HoldSignal.kneeExtension),
        isTrue,
      );
      expect(evaluation.isValidHoldPosture, isTrue);
    });

    test(
      'missing any required signal disables complete posture evaluation',
      () {
        for (final signals in <HoldSignalValues>[
          _signals(
            compressionAngle: null,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 170.0,
          ),
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: null,
            kneeExtensionAngle: 170.0,
          ),
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: null,
          ),
        ]) {
          final evaluation = policy.evaluate(signals, isHolding: true);

          expect(evaluation.hasCompleteMetrics, isFalse);
          expect(evaluation.isValidHoldPosture, isFalse);
          expect(evaluation.supportsGraceWindow, isFalse);
        }
      },
    );

    test(
      'compression failure selects the hollow compression corrective cue',
      () {
        final evaluation = policy.evaluate(
          _signals(
            compressionAngle: 171.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: true,
        );

        expect(
          evaluation.correctiveFeedbackCode,
          HoldFeedbackCode.increaseHollowCompression,
        );
      },
    );

    test('arm extension failure selects the overhead-arm corrective cue', () {
      final evaluation = policy.evaluate(
        _signals(
          compressionAngle: 150.0,
          armExtensionAngle: 119.0,
          kneeExtensionAngle: 170.0,
        ),
        isHolding: false,
      );

      expect(
        evaluation.correctiveFeedbackCode,
        HoldFeedbackCode.extendArmsOverhead,
      );
      expect(evaluation.supportsGraceWindow, isFalse);
    });

    test(
      'knee extension failure selects the straighten-knees corrective cue',
      () {
        final evaluation = policy.evaluate(
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 164.0,
          ),
          isHolding: false,
        );

        expect(
          evaluation.correctiveFeedbackCode,
          HoldFeedbackCode.straightenKnees,
        );
        expect(evaluation.supportsGraceWindow, isFalse);
      },
    );

    test(
      'multiple simultaneous failures follow deterministic cue priority',
      () {
        final compressionAndArmInvalid = policy.evaluate(
          _signals(
            compressionAngle: 171.0,
            armExtensionAngle: 119.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: true,
        );
        final armAndKneeInvalid = policy.evaluate(
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: 119.0,
            kneeExtensionAngle: 164.0,
          ),
          isHolding: false,
        );

        expect(
          compressionAndArmInvalid.correctiveFeedbackCode,
          HoldFeedbackCode.increaseHollowCompression,
        );
        expect(
          armAndKneeInvalid.correctiveFeedbackCode,
          HoldFeedbackCode.extendArmsOverhead,
        );
      },
    );

    test(
      'supports grace only for compression drift with valid arm and knee signals',
      () {
        final compressionOnly = policy.evaluate(
          _signals(
            compressionAngle: 171.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: true,
        );
        final armFailure = policy.evaluate(
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: 119.0,
            kneeExtensionAngle: 170.0,
          ),
          isHolding: true,
        );
        final kneeFailure = policy.evaluate(
          _signals(
            compressionAngle: 150.0,
            armExtensionAngle: 160.0,
            kneeExtensionAngle: 164.0,
          ),
          isHolding: true,
        );

        expect(compressionOnly.supportsGraceWindow, isTrue);
        expect(armFailure.supportsGraceWindow, isFalse);
        expect(kneeFailure.supportsGraceWindow, isFalse);
      },
    );
  });
}

HoldSignalValues _signals({
  required double? compressionAngle,
  required double? armExtensionAngle,
  required double? kneeExtensionAngle,
}) {
  final values = <HoldSignal, double>{};
  if (compressionAngle != null) {
    values[HoldSignal.compression] = compressionAngle;
  }
  if (armExtensionAngle != null) {
    values[HoldSignal.armExtension] = armExtensionAngle;
  }
  if (kneeExtensionAngle != null) {
    values[HoldSignal.kneeExtension] = kneeExtensionAngle;
  }
  return HoldSignalValues(values: values);
}
