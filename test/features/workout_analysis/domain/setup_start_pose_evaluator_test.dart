import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_start_pose.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/setup_start_pose_evaluator.dart';

void main() {
  const resolver = SetupStartPoseContractResolver();
  const evaluator = SetupStartPoseEvaluator();
  const catalog = ExerciseCatalog();

  group('SetupStartPoseContractResolver', () {
    test('resolves a non-empty contract for all 18 supported exercises', () {
      final contracts = <ExerciseType, SetupStartPoseContract>{
        for (final exercise in ExerciseType.values)
          exercise: resolver.resolve(
            exerciseType: exercise,
            setupContract: catalog
                .definitionFor(exercise)
                .analysisSetupContract,
          ),
      };

      expect(contracts, hasLength(18));
      for (final entry in contracts.entries) {
        expect(entry.value.exerciseType, entry.key);
        expect(entry.value.checks, isNotEmpty);
        expect(
          entry.value.family,
          catalog
              .definitionFor(entry.key)
              .analysisSetupContract
              .startPoseFamily,
        );
      }
    });

    test(
      'shares family checks while preserving exercise-specific additions',
      () {
        final plank = _contractFor(ExerciseType.plank);
        final pushUp = _contractFor(ExerciseType.pushUp);
        final hollowHold = _contractFor(ExerciseType.hollowHold);
        final sitUp = _contractFor(ExerciseType.sitUp);

        expect(plank.checks, pushUp.checks);
        expect(plank.family, StartPoseFamily.floorProneSupport);
        expect(hollowHold.family, StartPoseFamily.floorSupine);
        expect(
          hollowHold.checks,
          contains(SetupStartPoseCheck.hollowCompression),
        );
        expect(sitUp.checks, contains(SetupStartPoseCheck.kneesBent));
        expect(
          sitUp.checks,
          isNot(contains(SetupStartPoseCheck.hollowCompression)),
        );
      },
    );

    test(
      'rejects a catalog family mismatch instead of silently evaluating it',
      () {
        final mismatched = ExerciseSetupContract(
          bodyCoverage: SetupBodyCoverage(
            requiredRegions: const <SetupBodyRegion>{
              SetupBodyRegion.shoulders,
              SetupBodyRegion.hips,
              SetupBodyRegion.knees,
              SetupBodyRegion.ankles,
            },
          ),
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: const <SetupEnvironmentRequirement>{
            SetupEnvironmentRequirement.stableCamera,
            SetupEnvironmentRequirement.clearFloorArea,
          },
        );

        expect(
          () => resolver.resolve(
            exerciseType: ExerciseType.squat,
            setupContract: mismatched,
          ),
          throwsStateError,
        );
      },
    );
  });

  group('SetupStartPoseEvaluator', () {
    test('matches an upright neutral squat start pose', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.squat),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.5, 0.2),
          SetupStartPoseJoint.leftHip: _point(0.5, 0.45),
          SetupStartPoseJoint.leftKnee: _point(0.5, 0.65),
          SetupStartPoseJoint.leftAnkle: _point(0.5, 0.85),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.matched);
      expect(assessment.isMatched, isTrue);
      expect(assessment.failedChecks, isEmpty);
      expect(assessment.unavailableChecks, isEmpty);
    });

    test('rejects a squat pose that begins with a deeply bent knee', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.squat),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.5, 0.2),
          SetupStartPoseJoint.leftHip: _point(0.5, 0.45),
          SetupStartPoseJoint.leftKnee: _point(0.65, 0.6),
          SetupStartPoseJoint.leftAnkle: _point(0.5, 0.68),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.notMatched);
      expect(
        assessment.failedChecks,
        contains(SetupStartPoseCheck.kneesExtended),
      );
    });

    test('reports insufficient evidence instead of inventing a posture', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.squat),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.5, 0.2),
          SetupStartPoseJoint.leftHip: _point(0.5, 0.45),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.insufficientEvidence);
      expect(
        assessment.unavailableChecks,
        contains(SetupStartPoseCheck.kneesExtended),
      );
    });

    test('matches a horizontal straight-body support pose', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.plank),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.2, 0.5),
          SetupStartPoseJoint.leftElbow: _point(0.21, 0.63),
          SetupStartPoseJoint.leftWrist: _point(0.22, 0.72),
          SetupStartPoseJoint.leftHip: _point(0.5, 0.5),
          SetupStartPoseJoint.leftKnee: _point(0.68, 0.5),
          SetupStartPoseJoint.leftAnkle: _point(0.86, 0.5),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.matched);
      expect(
        assessment.passedChecks,
        containsAll(<SetupStartPoseCheck>{
          SetupStartPoseCheck.horizontalTorso,
          SetupStartPoseCheck.straightBodyLine,
          SetupStartPoseCheck.supportUnderShoulders,
        }),
      );
    });

    test('matches an arms-down standing exercise start pose', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.bicepsCurl),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.45, 0.2),
          SetupStartPoseJoint.leftElbow: _point(0.45, 0.43),
          SetupStartPoseJoint.leftWrist: _point(0.45, 0.66),
          SetupStartPoseJoint.leftHip: _point(0.45, 0.5),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.matched);
      expect(assessment.passedChecks, contains(SetupStartPoseCheck.armsDown));
    });

    test('matches a shoulder-press elbows-bent start pose', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.shoulderPress),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.4, 0.2),
          SetupStartPoseJoint.leftElbow: _point(0.4, 0.38),
          SetupStartPoseJoint.leftWrist: _point(0.57, 0.38),
          SetupStartPoseJoint.leftHip: _point(0.4, 0.5),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.matched);
      expect(assessment.passedChecks, contains(SetupStartPoseCheck.elbowsBent));
    });

    test('matches a wall-sit depth without running the hold engine', () {
      final assessment = evaluator.evaluate(
        contract: _contractFor(ExerciseType.wallSit),
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.4, 0.2),
          SetupStartPoseJoint.leftHip: _point(0.4, 0.45),
          SetupStartPoseJoint.leftKnee: _point(0.62, 0.45),
          SetupStartPoseJoint.leftAnkle: _point(0.62, 0.68),
        }),
      );

      expect(assessment.status, SetupStartPoseStatus.matched);
      expect(
        assessment.passedChecks,
        contains(SetupStartPoseCheck.wallSitDepth),
      );
    });

    test('protects contract and assessment collections', () {
      final checks = <SetupStartPoseCheck>{SetupStartPoseCheck.uprightTorso};
      final contract = SetupStartPoseContract(
        exerciseType: ExerciseType.squat,
        family: StartPoseFamily.standingNeutralSide,
        checks: checks,
      );
      checks.clear();
      final assessment = evaluator.evaluate(
        contract: contract,
        pose: _pose(<SetupStartPoseJoint, SetupStartPosePoint>{
          SetupStartPoseJoint.leftShoulder: _point(0.5, 0.2),
          SetupStartPoseJoint.leftHip: _point(0.5, 0.5),
        }),
      );

      expect(contract.checks, const <SetupStartPoseCheck>{
        SetupStartPoseCheck.uprightTorso,
      });
      expect(
        () => assessment.results[SetupStartPoseCheck.armsDown] =
            const SetupStartPoseCheckResult(
              check: SetupStartPoseCheck.armsDown,
              outcome: SetupStartPoseCheckOutcome.failed,
              confidence: 1,
            ),
        throwsUnsupportedError,
      );
    });
  });
}

SetupStartPoseContract _contractFor(ExerciseType exerciseType) {
  return const SetupStartPoseContractResolver().resolve(
    exerciseType: exerciseType,
    setupContract: const ExerciseCatalog()
        .definitionFor(exerciseType)
        .analysisSetupContract,
  );
}

SetupStartPose _pose(Map<SetupStartPoseJoint, SetupStartPosePoint> points) {
  return SetupStartPose(points: points);
}

SetupStartPosePoint _point(
  double x,
  double y, {
  double z = 0,
  double likelihood = 0.95,
}) {
  return SetupStartPosePoint(x: x, y: y, z: z, likelihood: likelihood);
}
