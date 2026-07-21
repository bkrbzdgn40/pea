import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_form_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/wall_sit_posture_policy.dart';

void main() {
  const policy = WallSitPosturePolicy(
    config: WallSitPostureConfig(
      activeKneeMaxAngle: 130,
      kneeMinAngle: 80,
      kneeMaxAngle: 120,
      hipMinAngle: 70,
      hipMaxAngle: 120,
      torsoMinAngle: 155,
      breakGraceDuration: Duration(milliseconds: 500),
    ),
  );

  HoldSignalValues values({
    double knee = 90,
    double hip = 90,
    double torso = 175,
  }) {
    return HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.kneeFlexion: knee,
        HoldSignal.hipFlexion: hip,
        HoldSignal.torsoAlignment: torso,
      },
    );
  }

  group('WallSitPosturePolicy', () {
    test('accepts a controlled wall-sit posture', () {
      final result = policy.evaluate(values(), isHolding: false);

      expect(result.hasActivePosture, isTrue);
      expect(result.hasCompleteMetrics, isTrue);
      expect(result.holdValidity, HoldValidityStatus.valid);
      expect(result.breakDisposition, HoldBreakDisposition.continueHold);
    });

    test(
      'missing measurements stay unknown instead of becoming a fake violation',
      () {
        final result = policy.evaluate(
          const HoldSignalValues.empty(),
          isHolding: false,
        );

        expect(result.hasCompleteMetrics, isFalse);
        expect(result.holdValidity, HoldValidityStatus.invalid);
        expect(result.correctiveFeedbackCode, HoldFeedbackCode.correctForm);
      },
    );

    test('rejects a shallow setup before a hold starts', () {
      final result = policy.evaluate(values(knee: 140), isHolding: false);

      expect(result.hasActivePosture, isFalse);
      expect(result.holdValidity, HoldValidityStatus.invalid);
      expect(result.breakDisposition, HoldBreakDisposition.breakImmediately);
      expect(
        result.correctiveFeedbackCode,
        HoldFeedbackCode.adjustWallSitDepth,
      );
    });

    test('allows a brief active-depth drift while already holding', () {
      final result = policy.evaluate(values(knee: 125), isHolding: true);

      expect(result.hasActivePosture, isTrue);
      expect(result.holdValidity, HoldValidityStatus.invalid);
      expect(result.breakDisposition, HoldBreakDisposition.graceEligible);
      expect(
        result.correctiveFeedbackCode,
        HoldFeedbackCode.adjustWallSitDepth,
      );
    });

    test('prioritizes torso correction when depth remains valid', () {
      final result = policy.evaluate(values(torso: 145), isHolding: true);

      expect(result.holdValidity, HoldValidityStatus.invalid);
      expect(result.breakDisposition, HoldBreakDisposition.graceEligible);
      expect(result.correctiveFeedbackCode, HoldFeedbackCode.alignWallSitTorso);
    });
  });
}
