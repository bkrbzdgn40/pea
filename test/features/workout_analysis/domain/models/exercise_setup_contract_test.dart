import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_setup_contract.dart';

void main() {
  test('setup enums keep the canonical roadmap values in order', () {
    expect(SetupBodyRegion.values, <SetupBodyRegion>[
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    ]);
    expect(SetupEnvironmentRequirement.values, <SetupEnvironmentRequirement>[
      SetupEnvironmentRequirement.stableCamera,
      SetupEnvironmentRequirement.adequateLighting,
      SetupEnvironmentRequirement.clearStandingArea,
      SetupEnvironmentRequirement.clearFloorArea,
      SetupEnvironmentRequirement.clearOverheadSpace,
      SetupEnvironmentRequirement.unobstructedWall,
      SetupEnvironmentRequirement.stableRaisedSurface,
    ]);
    expect(StartPoseFamily.values, <StartPoseFamily>[
      StartPoseFamily.standingNeutralSide,
      StartPoseFamily.standingArmsDownSide,
      StartPoseFamily.standingArmsDownFront,
      StartPoseFamily.standingElbowsBentFront,
      StartPoseFamily.splitStanceSide,
      StartPoseFamily.floorProneSupport,
      StartPoseFamily.floorSupine,
      StartPoseFamily.wallSupportedHold,
      StartPoseFamily.sideSupport,
      StartPoseFamily.dipSupport,
      StartPoseFamily.dynamicBilateralNeutral,
    ]);
    expect(SetupSupportSurface.values, <SetupSupportSurface>[
      SetupSupportSurface.none,
      SetupSupportSurface.floor,
      SetupSupportSurface.wall,
      SetupSupportSurface.raisedSurface,
    ]);
    expect(SetupCameraHeight.values, <SetupCameraHeight>[
      SetupCameraHeight.floorLevel,
      SetupCameraHeight.lowerBodyLevel,
      SetupCameraHeight.midBodyLevel,
      SetupCameraHeight.upperBodyLevel,
    ]);
  });

  test('copies and protects body coverage metadata', () {
    final source = <SetupBodyRegion>{SetupBodyRegion.shoulders};
    final coverage = SetupBodyCoverage(requiredRegions: source);

    source.add(SetupBodyRegion.hips);

    expect(coverage.requiredRegions, <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
    });
    expect(coverage.requires(SetupBodyRegion.shoulders), isTrue);
    expect(coverage.requires(SetupBodyRegion.hips), isFalse);
    expect(
      () => coverage.requiredRegions.add(SetupBodyRegion.hips),
      throwsUnsupportedError,
    );
  });

  test('rejects empty body coverage', () {
    expect(
      () => SetupBodyCoverage(requiredRegions: <SetupBodyRegion>{}),
      throwsArgumentError,
    );
  });

  test('copies and protects environment requirements', () {
    final source = <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
    };
    final contract = ExerciseSetupContract(
      bodyCoverage: SetupBodyCoverage(
        requiredRegions: <SetupBodyRegion>{SetupBodyRegion.hips},
      ),
      startPoseFamily: StartPoseFamily.standingNeutralSide,
      supportSurface: SetupSupportSurface.none,
      cameraHeight: SetupCameraHeight.midBodyLevel,
      environmentRequirements: source,
    );

    source.add(SetupEnvironmentRequirement.adequateLighting);

    expect(contract.environmentRequirements, <SetupEnvironmentRequirement>{
      SetupEnvironmentRequirement.stableCamera,
    });
    expect(
      contract.requiresEnvironment(SetupEnvironmentRequirement.stableCamera),
      isTrue,
    );
    expect(
      contract.requiresEnvironment(
        SetupEnvironmentRequirement.adequateLighting,
      ),
      isFalse,
    );
    expect(
      () => contract.environmentRequirements.add(
        SetupEnvironmentRequirement.adequateLighting,
      ),
      throwsUnsupportedError,
    );
  });

  test('rejects empty environment requirements', () {
    expect(
      () => ExerciseSetupContract(
        bodyCoverage: SetupBodyCoverage(
          requiredRegions: <SetupBodyRegion>{SetupBodyRegion.hips},
        ),
        startPoseFamily: StartPoseFamily.standingNeutralSide,
        supportSurface: SetupSupportSurface.none,
        cameraHeight: SetupCameraHeight.midBodyLevel,
        environmentRequirements: <SetupEnvironmentRequirement>{},
      ),
      throwsArgumentError,
    );
  });

  test('requires environment support for physical setup surfaces', () {
    final coverage = SetupBodyCoverage(
      requiredRegions: <SetupBodyRegion>{SetupBodyRegion.hips},
    );

    expect(
      () => ExerciseSetupContract(
        bodyCoverage: coverage,
        startPoseFamily: StartPoseFamily.floorSupine,
        supportSurface: SetupSupportSurface.floor,
        cameraHeight: SetupCameraHeight.floorLevel,
        environmentRequirements: <SetupEnvironmentRequirement>{
          SetupEnvironmentRequirement.stableCamera,
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseSetupContract(
        bodyCoverage: coverage,
        startPoseFamily: StartPoseFamily.wallSupportedHold,
        supportSurface: SetupSupportSurface.wall,
        cameraHeight: SetupCameraHeight.midBodyLevel,
        environmentRequirements: <SetupEnvironmentRequirement>{
          SetupEnvironmentRequirement.stableCamera,
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseSetupContract(
        bodyCoverage: coverage,
        startPoseFamily: StartPoseFamily.dipSupport,
        supportSurface: SetupSupportSurface.raisedSurface,
        cameraHeight: SetupCameraHeight.lowerBodyLevel,
        environmentRequirements: <SetupEnvironmentRequirement>{
          SetupEnvironmentRequirement.stableCamera,
        },
      ),
      throwsArgumentError,
    );
  });
}
