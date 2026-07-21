import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/assessment_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';

void main() {
  group('AssessmentEngine', () {
    test('requires start before observations', () {
      final engine = AssessmentEngine(type: AssessmentType.squat);

      expect(() => engine.observe(_squat(depth: 0.2)), throwsStateError);
    });

    test('squat assessment keeps the deepest complete sample', () {
      final engine = AssessmentEngine(type: AssessmentType.squat)..start();

      engine
        ..observe(
          _squat(
            leftKneeAngle: 100,
            rightKneeAngle: 104,
            depth: 0.25,
            torso: 12,
          ),
        )
        ..observe(
          _squat(
            leftKneeAngle: 82,
            rightKneeAngle: 88,
            depth: -0.10,
            torso: 22,
          ),
        )
        ..observe(
          _squat(leftKneeAngle: 92, rightKneeAngle: 93, depth: 0.05, torso: 18),
        );

      final result = engine.complete() as SquatAssessmentResult;

      expect(result.sampleCount, 3);
      expect(result.hasSufficientData, isTrue);
      expect(result.leftKneeFlexionDegrees, 98);
      expect(result.rightKneeFlexionDegrees, 92);
      expect(result.kneeFlexionAsymmetryDegrees, 6);
      expect(result.deepestHipDepthRatio, -0.10);
      expect(result.torsoInclinationAtDeepestDegrees, 22);
      expect(result.reachedHipAtOrBelowKneeHeight, isTrue);
    });

    test('squat assessment ignores incomplete samples without fake zeroes', () {
      final engine = AssessmentEngine(type: AssessmentType.squat)..start();

      engine.observe(
        const SquatAssessmentObservation(
          leftKneeAngleDegrees: 90,
          rightKneeAngleDegrees: null,
          hipDepthRatio: -0.1,
          torsoInclinationDegrees: 15,
        ),
      );

      final result = engine.complete() as SquatAssessmentResult;

      expect(result.sampleCount, 0);
      expect(result.hasSufficientData, isFalse);
      expect(result.leftKneeFlexionDegrees, isNull);
      expect(result.deepestHipDepthRatio, isNull);
    });

    test('balance assessment requires an explicit stance side', () {
      final engine = AssessmentEngine(type: AssessmentType.balance);

      expect(() => engine.start(), throwsArgumentError);
    });

    test('balance assessment rejects observations for the other side', () {
      final engine = AssessmentEngine(
        type: AssessmentType.balance,
        config: const AssessmentEngineConfig(
          minimumBalanceSamples: 2,
          minimumBalanceDuration: Duration(seconds: 1),
        ),
      )..start(balanceSide: AssessmentSide.left);

      expect(
        () => engine.observe(
          _balance(
            side: AssessmentSide.right,
            second: 0,
            shoulderX: 1,
            hipX: 1,
            clearance: 0.2,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('balance assessment rejects frames without one-leg clearance', () {
      final engine = AssessmentEngine(
        type: AssessmentType.balance,
        config: const AssessmentEngineConfig(
          minimumBalanceSamples: 2,
          minimumBalanceDuration: Duration(seconds: 1),
        ),
      )..start(balanceSide: AssessmentSide.left);

      engine
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 0,
            shoulderX: 1,
            hipX: 1,
            clearance: 0.05,
          ),
        )
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 1,
            shoulderX: 1,
            hipX: 1,
            clearance: 0.2,
          ),
        );

      final result = engine.complete() as BalanceAssessmentResult;

      expect(result.sampleCount, 1);
      expect(result.rejectedSampleCount, 1);
      expect(result.hasSufficientData, isFalse);
    });

    test('stable balance samples produce a maximum heuristic score', () {
      final engine = AssessmentEngine(
        type: AssessmentType.balance,
        config: const AssessmentEngineConfig(
          minimumBalanceSamples: 2,
          minimumBalanceDuration: Duration(seconds: 1),
        ),
      )..start(balanceSide: AssessmentSide.left);

      engine
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 0,
            shoulderX: 1.2,
            hipX: 1.0,
            clearance: 0.2,
          ),
        )
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 1,
            shoulderX: 1.2,
            hipX: 1.0,
            clearance: 0.2,
          ),
        );

      final result = engine.complete() as BalanceAssessmentResult;

      expect(result.hasSufficientData, isTrue);
      expect(result.stabilityScore, 100);
      expect(result.averageSwayStandardDeviation, 0);
      expect(result.observedDuration, const Duration(seconds: 1));
    });

    test('balance score stays null until duration evidence is sufficient', () {
      final engine = AssessmentEngine(
        type: AssessmentType.balance,
        config: const AssessmentEngineConfig(
          minimumBalanceSamples: 2,
          minimumBalanceDuration: Duration(seconds: 5),
        ),
      )..start(balanceSide: AssessmentSide.left);

      engine
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 0,
            shoulderX: 1.0,
            hipX: 1.0,
            clearance: 0.2,
          ),
        )
        ..observe(
          _balance(
            side: AssessmentSide.left,
            second: 1,
            shoulderX: 1.0,
            hipX: 1.0,
            clearance: 0.2,
          ),
        );

      final result = engine.complete() as BalanceAssessmentResult;

      expect(result.sampleCount, 2);
      expect(result.hasSufficientData, isFalse);
      expect(result.stabilityScore, isNull);
    });

    test('larger image-plane sway lowers the balance heuristic score', () {
      final engine = AssessmentEngine(
        type: AssessmentType.balance,
        config: const AssessmentEngineConfig(
          minimumBalanceSamples: 2,
          minimumBalanceDuration: Duration(seconds: 1),
          balanceStandardDeviationAtZeroScore: 0.10,
        ),
      )..start(balanceSide: AssessmentSide.right);

      engine
        ..observe(
          _balance(
            side: AssessmentSide.right,
            second: 0,
            shoulderX: 1.0,
            hipX: 1.0,
            clearance: 0.2,
          ),
        )
        ..observe(
          _balance(
            side: AssessmentSide.right,
            second: 1,
            shoulderX: 1.2,
            hipX: 1.2,
            clearance: 0.2,
          ),
        );

      final result = engine.complete() as BalanceAssessmentResult;

      expect(result.stabilityScore, closeTo(0, 1e-9));
      expect(result.shoulderSwayStandardDeviation, closeTo(0.1, 1e-9));
      expect(result.hipSwayStandardDeviation, closeTo(0.1, 1e-9));
    });

    test('shoulder mobility keeps independent maxima for both sides', () {
      final engine = AssessmentEngine(type: AssessmentType.shoulderMobility)
        ..start();

      engine
        ..observe(
          const ShoulderMobilityAssessmentObservation(
            leftElevationDegrees: 140,
            rightElevationDegrees: 150,
            torsoInclinationDegrees: 8,
          ),
        )
        ..observe(
          const ShoulderMobilityAssessmentObservation(
            leftElevationDegrees: 165,
            rightElevationDegrees: 145,
            torsoInclinationDegrees: 12,
          ),
        )
        ..observe(
          const ShoulderMobilityAssessmentObservation(
            leftElevationDegrees: 160,
            rightElevationDegrees: 170,
            torsoInclinationDegrees: 18,
          ),
        );

      final result = engine.complete() as ShoulderMobilityAssessmentResult;

      expect(result.sampleCount, 3);
      expect(result.hasSufficientData, isTrue);
      expect(result.leftMaximumElevationDegrees, 165);
      expect(result.rightMaximumElevationDegrees, 170);
      expect(result.sideDifferenceDegrees, 5);
      expect(result.torsoInclinationAtLeftMaximumDegrees, 12);
      expect(result.torsoInclinationAtRightMaximumDegrees, 18);
    });

    test('shoulder mobility preserves missing-side evidence as null', () {
      final engine = AssessmentEngine(type: AssessmentType.shoulderMobility)
        ..start()
        ..observe(
          const ShoulderMobilityAssessmentObservation(
            leftElevationDegrees: 160,
            rightElevationDegrees: null,
            torsoInclinationDegrees: 10,
          ),
        );

      final result = engine.complete() as ShoulderMobilityAssessmentResult;

      expect(result.hasSufficientData, isFalse);
      expect(result.leftMaximumElevationDegrees, 160);
      expect(result.rightMaximumElevationDegrees, isNull);
      expect(result.sideDifferenceDegrees, isNull);
    });

    test('rejects an observation from another assessment type', () {
      final engine = AssessmentEngine(type: AssessmentType.squat)..start();

      expect(
        () => engine.observe(
          const ShoulderMobilityAssessmentObservation(
            leftElevationDegrees: 150,
            rightElevationDegrees: 150,
            torsoInclinationDegrees: 0,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('reset clears completed assessment state', () {
      final engine = AssessmentEngine(type: AssessmentType.squat)
        ..start()
        ..observe(_squat(depth: -0.1));
      engine.complete();

      final snapshot = engine.reset();

      expect(snapshot.phase, AssessmentPhase.idle);
      expect(snapshot.sampleCount, 0);
      expect(snapshot.result, isNull);
    });
  });
}

SquatAssessmentObservation _squat({
  double leftKneeAngle = 90,
  double rightKneeAngle = 90,
  required double depth,
  double torso = 10,
}) {
  return SquatAssessmentObservation(
    leftKneeAngleDegrees: leftKneeAngle,
    rightKneeAngleDegrees: rightKneeAngle,
    hipDepthRatio: depth,
    torsoInclinationDegrees: torso,
  );
}

BalanceAssessmentObservation _balance({
  required AssessmentSide side,
  required int second,
  required double shoulderX,
  required double hipX,
  required double clearance,
}) {
  return BalanceAssessmentObservation(
    side: side,
    capturedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
    shoulderCenterXNormalized: shoulderX,
    hipCenterXNormalized: hipX,
    raisedFootClearanceRatio: clearance,
  );
}
