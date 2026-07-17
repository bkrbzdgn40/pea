import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_form_policy.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_posture_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

void main() {
  final policy = HoldPosturePolicy(config: _holdConfig().resolvedHoldPosture);

  group('HoldPosturePolicy', () {
    test('implements the generic hold form policy contract', () {
      expect(policy, isA<HoldFormPolicy>());
      expect(policy.breakGraceDuration, const Duration(milliseconds: 300));
    });

    test('uses entry and sustain thresholds as hysteresis targets', () {
      final entryEvaluation = policy.evaluate(
        _signals(
          bodyLineAngle: 167.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
        ),
        isHolding: false,
      );
      final sustainEvaluation = policy.evaluate(
        _signals(
          bodyLineAngle: 167.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
        ),
        isHolding: true,
      );

      expect(
        entryEvaluation.targetSignalValues.valueFor(HoldSignal.alignment),
        168.0,
      );
      expect(entryEvaluation.postureDiagnostics.isBodyAligned, isFalse);
      expect(entryEvaluation.isValidHoldPosture, isFalse);
      expect(
        sustainEvaluation.targetSignalValues.valueFor(HoldSignal.alignment),
        166.0,
      );
      expect(sustainEvaluation.postureDiagnostics.isBodyAligned, isTrue);
      expect(sustainEvaluation.isValidHoldPosture, isTrue);
    });

    test(
      'treats boundary values as inclusive and outside values as invalid',
      () {
        final entryBoundary = policy.evaluate(
          _signals(
            bodyLineAngle: 168.0,
            armSupportAngle: 60.0,
            legExtensionAngle: 165.0,
          ),
          isHolding: false,
        );
        final upperArmBoundary = policy.evaluate(
          _signals(
            bodyLineAngle: 168.0,
            armSupportAngle: 120.0,
            legExtensionAngle: 165.0,
          ),
          isHolding: false,
        );
        final lowArmEvaluation = policy.evaluate(
          _signals(
            bodyLineAngle: 168.0,
            armSupportAngle: 59.0,
            legExtensionAngle: 165.0,
          ),
          isHolding: false,
        );
        final highArmEvaluation = policy.evaluate(
          _signals(
            bodyLineAngle: 168.0,
            armSupportAngle: 121.0,
            legExtensionAngle: 165.0,
          ),
          isHolding: false,
        );
        final lowLegEvaluation = policy.evaluate(
          _signals(
            bodyLineAngle: 168.0,
            armSupportAngle: 90.0,
            legExtensionAngle: 164.0,
          ),
          isHolding: false,
        );

        expect(entryBoundary.postureDiagnostics.isBodyAligned, isTrue);
        expect(entryBoundary.postureDiagnostics.isArmSupported, isTrue);
        expect(entryBoundary.postureDiagnostics.areLegsExtended, isTrue);
        expect(entryBoundary.isValidHoldPosture, isTrue);
        expect(upperArmBoundary.postureDiagnostics.isArmSupported, isTrue);
        expect(lowArmEvaluation.postureDiagnostics.isArmSupported, isFalse);
        expect(highArmEvaluation.postureDiagnostics.isArmSupported, isFalse);
        expect(lowLegEvaluation.postureDiagnostics.areLegsExtended, isFalse);
      },
    );

    for (final scenario
        in <
          ({
            String name,
            double? bodyLineAngle,
            double? armSupportAngle,
            double? legExtensionAngle,
          })
        >[
          (
            name: 'missing body line metric',
            bodyLineAngle: null,
            armSupportAngle: 90.0,
            legExtensionAngle: 170.0,
          ),
          (
            name: 'missing arm support metric',
            bodyLineAngle: 170.0,
            armSupportAngle: null,
            legExtensionAngle: 170.0,
          ),
          (
            name: 'missing leg extension metric',
            bodyLineAngle: 170.0,
            armSupportAngle: 90.0,
            legExtensionAngle: null,
          ),
        ]) {
      test(
        '${scenario.name} disables complete-posture and grace evaluation',
        () {
          final evaluation = policy.evaluate(
            _signals(
              bodyLineAngle: scenario.bodyLineAngle,
              armSupportAngle: scenario.armSupportAngle,
              legExtensionAngle: scenario.legExtensionAngle,
            ),
            isHolding: true,
          );

          expect(evaluation.hasCompleteMetrics, isFalse);
          expect(evaluation.isValidHoldPosture, isFalse);
          expect(evaluation.supportsGraceWindow, isFalse);
        },
      );
    }

    test(
      'supports grace only for body misalignment with valid arm and leg metrics',
      () {
        final bodyMisaligned = policy.evaluate(
          _signals(
            bodyLineAngle: 165.0,
            armSupportAngle: 90.0,
            legExtensionAngle: 170.0,
          ),
          isHolding: true,
        );
        final armInvalid = policy.evaluate(
          _signals(
            bodyLineAngle: 170.0,
            armSupportAngle: 59.0,
            legExtensionAngle: 170.0,
          ),
          isHolding: true,
        );
        final legInvalid = policy.evaluate(
          _signals(
            bodyLineAngle: 170.0,
            armSupportAngle: 90.0,
            legExtensionAngle: 164.0,
          ),
          isHolding: true,
        );

        expect(bodyMisaligned.supportsGraceWindow, isTrue);
        expect(
          bodyMisaligned.correctiveFeedbackCode,
          HoldFeedbackCode.alignHips,
        );
        expect(
          armInvalid.correctiveFeedbackCode,
          HoldFeedbackCode.adjustElbowSupport,
        );
        expect(legInvalid.correctiveFeedbackCode, HoldFeedbackCode.extendLegs);
        expect(armInvalid.supportsGraceWindow, isFalse);
        expect(legInvalid.supportsGraceWindow, isFalse);
      },
    );

    test('active posture remains distinct from valid hold posture', () {
      final evaluation = policy.evaluate(
        _signals(
          bodyLineAngle: 162.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
        ),
        isHolding: false,
      );

      expect(evaluation.hasActivePosture, isTrue);
      expect(evaluation.postureDiagnostics.isBodyAligned, isFalse);
      expect(evaluation.isValidHoldPosture, isFalse);
    });
  });
}

ExerciseConfig _holdConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
  );
}

HoldSignalValues _signals({
  double? bodyLineAngle,
  double? armSupportAngle,
  double? legExtensionAngle,
}) {
  return HoldSignalValues.legacy(
    alignment: bodyLineAngle,
    support: armSupportAngle,
    extension: legExtensionAngle,
  );
}
