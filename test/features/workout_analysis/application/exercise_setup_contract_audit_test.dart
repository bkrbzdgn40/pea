import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const catalog = ExerciseCatalog();

  test('registers a setup contract for every canonical exercise', () {
    for (final type in ExerciseType.values) {
      final definition = catalog.definitionFor(type);

      expect(definition.setupContract, isNotNull, reason: type.id);
      expect(
        definition.analysisSetupContract,
        same(definition.setupContract),
        reason: type.id,
      );
      expect(
        definition.analysisSetupContract.bodyCoverage.requiredRegions,
        isNotEmpty,
        reason: type.id,
      );
      expect(
        definition.analysisSetupContract.environmentRequirements,
        containsAll(<SetupEnvironmentRequirement>{
          SetupEnvironmentRequirement.stableCamera,
          SetupEnvironmentRequirement.adequateLighting,
        }),
        reason: type.id,
      );
    }
  });

  test('maps every exercise to the intended start-pose family', () {
    const expected = <ExerciseType, StartPoseFamily>{
      ExerciseType.squat: StartPoseFamily.standingNeutralSide,
      ExerciseType.plank: StartPoseFamily.floorProneSupport,
      ExerciseType.hollowHold: StartPoseFamily.floorSupine,
      ExerciseType.lunge: StartPoseFamily.splitStanceSide,
      ExerciseType.pushUp: StartPoseFamily.floorProneSupport,
      ExerciseType.sitUp: StartPoseFamily.floorSupine,
      ExerciseType.bicepsCurl: StartPoseFamily.standingArmsDownFront,
      ExerciseType.lyingLegRaise: StartPoseFamily.floorSupine,
      ExerciseType.tricepsDip: StartPoseFamily.dipSupport,
      ExerciseType.romanianDeadlift: StartPoseFamily.standingNeutralSide,
      ExerciseType.goodMorning: StartPoseFamily.standingNeutralSide,
      ExerciseType.lateralRaise: StartPoseFamily.standingArmsDownFront,
      ExerciseType.shoulderPress: StartPoseFamily.standingElbowsBentFront,
      ExerciseType.calfRaise: StartPoseFamily.standingNeutralSide,
      ExerciseType.frontRaise: StartPoseFamily.standingArmsDownSide,
      ExerciseType.gluteBridge: StartPoseFamily.floorSupine,
      ExerciseType.wallSit: StartPoseFamily.wallSupportedHold,
      ExerciseType.sidePlank: StartPoseFamily.sideSupport,
      ExerciseType.jumpingJack: StartPoseFamily.dynamicBilateralNeutral,
    };

    expect(expected.keys, unorderedEquals(ExerciseType.values));
    for (final entry in expected.entries) {
      expect(
        catalog.definitionFor(entry.key).analysisSetupContract.startPoseFamily,
        entry.value,
        reason: entry.key.id,
      );
    }
  });

  test('maps every exercise to the intended support surface', () {
    const expected = <ExerciseType, SetupSupportSurface>{
      ExerciseType.squat: SetupSupportSurface.none,
      ExerciseType.plank: SetupSupportSurface.floor,
      ExerciseType.hollowHold: SetupSupportSurface.floor,
      ExerciseType.lunge: SetupSupportSurface.none,
      ExerciseType.pushUp: SetupSupportSurface.floor,
      ExerciseType.sitUp: SetupSupportSurface.floor,
      ExerciseType.bicepsCurl: SetupSupportSurface.none,
      ExerciseType.lyingLegRaise: SetupSupportSurface.floor,
      ExerciseType.tricepsDip: SetupSupportSurface.raisedSurface,
      ExerciseType.romanianDeadlift: SetupSupportSurface.none,
      ExerciseType.goodMorning: SetupSupportSurface.none,
      ExerciseType.lateralRaise: SetupSupportSurface.none,
      ExerciseType.shoulderPress: SetupSupportSurface.none,
      ExerciseType.calfRaise: SetupSupportSurface.none,
      ExerciseType.frontRaise: SetupSupportSurface.none,
      ExerciseType.gluteBridge: SetupSupportSurface.floor,
      ExerciseType.wallSit: SetupSupportSurface.wall,
      ExerciseType.sidePlank: SetupSupportSurface.floor,
      ExerciseType.jumpingJack: SetupSupportSurface.none,
    };

    expect(expected.keys, unorderedEquals(ExerciseType.values));
    for (final entry in expected.entries) {
      expect(
        catalog.definitionFor(entry.key).analysisSetupContract.supportSurface,
        entry.value,
        reason: entry.key.id,
      );
    }
  });

  test('maps semantic camera height for every exercise', () {
    const expected = <ExerciseType, SetupCameraHeight>{
      ExerciseType.squat: SetupCameraHeight.midBodyLevel,
      ExerciseType.plank: SetupCameraHeight.floorLevel,
      ExerciseType.hollowHold: SetupCameraHeight.floorLevel,
      ExerciseType.lunge: SetupCameraHeight.midBodyLevel,
      ExerciseType.pushUp: SetupCameraHeight.floorLevel,
      ExerciseType.sitUp: SetupCameraHeight.floorLevel,
      ExerciseType.bicepsCurl: SetupCameraHeight.upperBodyLevel,
      ExerciseType.lyingLegRaise: SetupCameraHeight.floorLevel,
      ExerciseType.tricepsDip: SetupCameraHeight.lowerBodyLevel,
      ExerciseType.romanianDeadlift: SetupCameraHeight.midBodyLevel,
      ExerciseType.goodMorning: SetupCameraHeight.midBodyLevel,
      ExerciseType.lateralRaise: SetupCameraHeight.upperBodyLevel,
      ExerciseType.shoulderPress: SetupCameraHeight.upperBodyLevel,
      ExerciseType.calfRaise: SetupCameraHeight.lowerBodyLevel,
      ExerciseType.frontRaise: SetupCameraHeight.upperBodyLevel,
      ExerciseType.gluteBridge: SetupCameraHeight.floorLevel,
      ExerciseType.wallSit: SetupCameraHeight.midBodyLevel,
      ExerciseType.sidePlank: SetupCameraHeight.floorLevel,
      ExerciseType.jumpingJack: SetupCameraHeight.midBodyLevel,
    };

    expect(expected.keys, unorderedEquals(ExerciseType.values));
    for (final entry in expected.entries) {
      expect(
        catalog.definitionFor(entry.key).analysisSetupContract.cameraHeight,
        entry.value,
        reason: entry.key.id,
      );
    }
  });

  test('declares exercise-specific body coverage', () {
    const fullBody = <SetupBodyRegion>{
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    };
    const headToFeet = <SetupBodyRegion>{
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    };
    const upperBody = <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
    };
    const upperBodyWithHead = <SetupBodyRegion>{
      SetupBodyRegion.head,
      ...upperBody,
    };
    const sideChain = <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    };
    const lowerBody = <SetupBodyRegion>{
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    };
    const dipCoverage = <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    };
    const expected = <ExerciseType, Set<SetupBodyRegion>>{
      ExerciseType.squat: headToFeet,
      ExerciseType.plank: fullBody,
      ExerciseType.hollowHold: fullBody,
      ExerciseType.lunge: headToFeet,
      ExerciseType.pushUp: fullBody,
      ExerciseType.sitUp: headToFeet,
      ExerciseType.bicepsCurl: upperBody,
      ExerciseType.lyingLegRaise: sideChain,
      ExerciseType.tricepsDip: dipCoverage,
      ExerciseType.romanianDeadlift: sideChain,
      ExerciseType.goodMorning: sideChain,
      ExerciseType.lateralRaise: upperBody,
      ExerciseType.shoulderPress: upperBodyWithHead,
      ExerciseType.calfRaise: lowerBody,
      ExerciseType.frontRaise: upperBody,
      ExerciseType.gluteBridge: sideChain,
      ExerciseType.wallSit: headToFeet,
      ExerciseType.sidePlank: fullBody,
      ExerciseType.jumpingJack: fullBody,
    };

    expect(expected.keys, unorderedEquals(ExerciseType.values));
    for (final entry in expected.entries) {
      expect(
        catalog
            .definitionFor(entry.key)
            .analysisSetupContract
            .bodyCoverage
            .requiredRegions,
        entry.value,
        reason: entry.key.id,
      );
    }
  });

  test(
    'declares the environment required by floor, wall, and bench setups',
    () {
      for (final type in const <ExerciseType>[
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
        ExerciseType.lyingLegRaise,
        ExerciseType.gluteBridge,
        ExerciseType.sidePlank,
      ]) {
        expect(
          catalog
              .definitionFor(type)
              .analysisSetupContract
              .requiresEnvironment(SetupEnvironmentRequirement.clearFloorArea),
          isTrue,
          reason: type.id,
        );
      }

      final wallSit = catalog.definitionFor(ExerciseType.wallSit);
      expect(
        wallSit.analysisSetupContract.requiresEnvironment(
          SetupEnvironmentRequirement.unobstructedWall,
        ),
        isTrue,
      );

      final dip = catalog.definitionFor(ExerciseType.tricepsDip);
      expect(
        dip.analysisSetupContract.requiresEnvironment(
          SetupEnvironmentRequirement.stableRaisedSurface,
        ),
        isTrue,
      );

      for (final type in const <ExerciseType>[
        ExerciseType.shoulderPress,
        ExerciseType.jumpingJack,
      ]) {
        expect(
          catalog
              .definitionFor(type)
              .analysisSetupContract
              .requiresEnvironment(
                SetupEnvironmentRequirement.clearOverheadSpace,
              ),
          isTrue,
          reason: type.id,
        );
      }
    },
  );
}
