/// Semantic body regions that must remain visible during exercise setup.
enum SetupBodyRegion {
  head,
  shoulders,
  elbows,
  wrists,
  hips,
  knees,
  ankles,
  feet,
}

/// Exercise-aware environment conditions required before analysis begins.
enum SetupEnvironmentRequirement {
  stableCamera,
  adequateLighting,
  clearStandingArea,
  clearFloorArea,
  clearOverheadSpace,
  unobstructedWall,
  stableRaisedSurface,
}

/// Canonical start-pose families shared by exercises with similar setup needs.
enum StartPoseFamily {
  standingNeutralSide,
  standingArmsDownSide,
  standingArmsDownFront,
  standingElbowsBentFront,
  splitStanceSide,
  floorProneSupport,
  floorSupine,
  wallSupportedHold,
  sideSupport,
  dipSupport,
  dynamicBilateralNeutral,
}

/// Physical surface that supports the user during the exercise setup.
enum SetupSupportSurface { none, floor, wall, raisedSurface }

/// Approximate semantic phone height used by later presentation/readiness layers.
enum SetupCameraHeight {
  floorLevel,
  lowerBodyLevel,
  midBodyLevel,
  upperBodyLevel,
}

/// Declares the body regions that must fit inside the camera frame.
class SetupBodyCoverage {
  SetupBodyCoverage({required Set<SetupBodyRegion> requiredRegions})
    : requiredRegions = Set<SetupBodyRegion>.unmodifiable(requiredRegions) {
    if (this.requiredRegions.isEmpty) {
      throw ArgumentError.value(
        requiredRegions,
        'requiredRegions',
        'Setup body coverage must contain at least one body region.',
      );
    }
  }

  final Set<SetupBodyRegion> requiredRegions;

  bool requires(SetupBodyRegion region) => requiredRegions.contains(region);
}

/// Central, presentation-independent preparation contract for an exercise.
///
/// Camera orientation remains owned by `CameraViewContract` on the same
/// `ExerciseDefinition`; this model intentionally does not duplicate it.
class ExerciseSetupContract {
  ExerciseSetupContract({
    required this.bodyCoverage,
    required this.startPoseFamily,
    required this.supportSurface,
    required this.cameraHeight,
    required Set<SetupEnvironmentRequirement> environmentRequirements,
  }) : environmentRequirements = Set<SetupEnvironmentRequirement>.unmodifiable(
         environmentRequirements,
       ) {
    if (this.environmentRequirements.isEmpty) {
      throw ArgumentError.value(
        environmentRequirements,
        'environmentRequirements',
        'Exercise setup must declare at least one environment requirement.',
      );
    }

    switch (supportSurface) {
      case SetupSupportSurface.none:
        break;
      case SetupSupportSurface.floor:
        _requireEnvironment(SetupEnvironmentRequirement.clearFloorArea);
        break;
      case SetupSupportSurface.wall:
        _requireEnvironment(SetupEnvironmentRequirement.unobstructedWall);
        break;
      case SetupSupportSurface.raisedSurface:
        _requireEnvironment(SetupEnvironmentRequirement.stableRaisedSurface);
        break;
    }
  }

  final SetupBodyCoverage bodyCoverage;
  final StartPoseFamily startPoseFamily;
  final SetupSupportSurface supportSurface;
  final SetupCameraHeight cameraHeight;
  final Set<SetupEnvironmentRequirement> environmentRequirements;

  bool requiresEnvironment(SetupEnvironmentRequirement requirement) {
    return environmentRequirements.contains(requirement);
  }

  void _requireEnvironment(SetupEnvironmentRequirement requirement) {
    if (environmentRequirements.contains(requirement)) {
      return;
    }

    throw ArgumentError.value(
      environmentRequirements,
      'environmentRequirements',
      '${supportSurface.name} setup requires ${requirement.name}.',
    );
  }
}
