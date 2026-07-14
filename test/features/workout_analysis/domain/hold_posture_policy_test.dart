import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_posture_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';

void main() {
  final policy = HoldPosturePolicy(config: _holdConfig().resolvedHoldPosture);

  group('HoldPosturePolicy', () {
    test('uses entry and sustain thresholds as hysteresis targets', () {
      final entryEvaluation = policy.evaluate(
        bodyLineAngle: 167.0,
        armSupportAngle: 90.0,
        legExtensionAngle: 170.0,
        isHolding: false,
      );
      final sustainEvaluation = policy.evaluate(
        bodyLineAngle: 167.0,
        armSupportAngle: 90.0,
        legExtensionAngle: 170.0,
        isHolding: true,
      );

      expect(entryEvaluation.bodyLineTargetAngle, 168.0);
      expect(entryEvaluation.isBodyAligned, isFalse);
      expect(entryEvaluation.isValidHoldPosture, isFalse);
      expect(sustainEvaluation.bodyLineTargetAngle, 166.0);
      expect(sustainEvaluation.isBodyAligned, isTrue);
      expect(sustainEvaluation.isValidHoldPosture, isTrue);
    });

    test(
      'treats boundary values as inclusive and outside values as invalid',
      () {
        final entryBoundary = policy.evaluate(
          bodyLineAngle: 168.0,
          armSupportAngle: 60.0,
          legExtensionAngle: 165.0,
          isHolding: false,
        );
        final upperArmBoundary = policy.evaluate(
          bodyLineAngle: 168.0,
          armSupportAngle: 120.0,
          legExtensionAngle: 165.0,
          isHolding: false,
        );
        final lowArmEvaluation = policy.evaluate(
          bodyLineAngle: 168.0,
          armSupportAngle: 59.0,
          legExtensionAngle: 165.0,
          isHolding: false,
        );
        final highArmEvaluation = policy.evaluate(
          bodyLineAngle: 168.0,
          armSupportAngle: 121.0,
          legExtensionAngle: 165.0,
          isHolding: false,
        );
        final lowLegEvaluation = policy.evaluate(
          bodyLineAngle: 168.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 164.0,
          isHolding: false,
        );

        expect(entryBoundary.isBodyAligned, isTrue);
        expect(entryBoundary.isArmSupported, isTrue);
        expect(entryBoundary.areLegsExtended, isTrue);
        expect(entryBoundary.isValidHoldPosture, isTrue);
        expect(upperArmBoundary.isArmSupported, isTrue);
        expect(lowArmEvaluation.isArmSupported, isFalse);
        expect(highArmEvaluation.isArmSupported, isFalse);
        expect(lowLegEvaluation.areLegsExtended, isFalse);
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
            bodyLineAngle: scenario.bodyLineAngle,
            armSupportAngle: scenario.armSupportAngle,
            legExtensionAngle: scenario.legExtensionAngle,
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
          bodyLineAngle: 165.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
          isHolding: true,
        );
        final armInvalid = policy.evaluate(
          bodyLineAngle: 170.0,
          armSupportAngle: 59.0,
          legExtensionAngle: 170.0,
          isHolding: true,
        );
        final legInvalid = policy.evaluate(
          bodyLineAngle: 170.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 164.0,
          isHolding: true,
        );

        expect(bodyMisaligned.supportsGraceWindow, isTrue);
        expect(armInvalid.supportsGraceWindow, isFalse);
        expect(legInvalid.supportsGraceWindow, isFalse);
      },
    );

    test('active posture remains distinct from valid hold posture', () {
      final evaluation = policy.evaluate(
        bodyLineAngle: 162.0,
        armSupportAngle: 90.0,
        legExtensionAngle: 170.0,
        isHolding: false,
      );

      expect(evaluation.hasActivePosture, isTrue);
      expect(evaluation.isBodyAligned, isFalse);
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
