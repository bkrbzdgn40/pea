import '../domain/models/camera_view_contract.dart';
import '../domain/models/exercise_setup_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_validation_policy.dart';
import 'engine_kind.dart';
import 'exercise_definition.dart';
import 'exercise_definition_metadata.dart';
import 'exercise_metric_registry.dart';

/// Central exercise metadata source for analysis capability.
class ExerciseCatalog {
  const ExerciseCatalog();

  static final SetupBodyCoverage _fullBodyCoverage = SetupBodyCoverage(
    requiredRegions: SetupBodyRegion.values.toSet(),
  );
  static final SetupBodyCoverage _headToFeetCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    },
  );
  static final SetupBodyCoverage _upperBodyCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
    },
  );
  static final SetupBodyCoverage _upperBodyWithHeadCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
    },
  );
  static final SetupBodyCoverage _sideChainCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    },
  );
  static final SetupBodyCoverage _headToAnklesCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.head,
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
    },
  );
  static final SetupBodyCoverage _floorLegCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
    },
  );
  static final SetupBodyCoverage _floorPressCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
    },
  );
  static final SetupBodyCoverage _lowerBodyCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    },
  );
  static final SetupBodyCoverage _dipCoverage = SetupBodyCoverage(
    requiredRegions: const <SetupBodyRegion>{
      SetupBodyRegion.shoulders,
      SetupBodyRegion.elbows,
      SetupBodyRegion.wrists,
      SetupBodyRegion.hips,
      SetupBodyRegion.knees,
      SetupBodyRegion.ankles,
      SetupBodyRegion.feet,
    },
  );

  static const Set<SetupEnvironmentRequirement> _standingEnvironment =
      <SetupEnvironmentRequirement>{
        SetupEnvironmentRequirement.stableCamera,
        SetupEnvironmentRequirement.adequateLighting,
        SetupEnvironmentRequirement.clearStandingArea,
      };
  static const Set<SetupEnvironmentRequirement> _standingOverheadEnvironment =
      <SetupEnvironmentRequirement>{
        ..._standingEnvironment,
        SetupEnvironmentRequirement.clearOverheadSpace,
      };
  static const Set<SetupEnvironmentRequirement> _floorEnvironment =
      <SetupEnvironmentRequirement>{
        SetupEnvironmentRequirement.stableCamera,
        SetupEnvironmentRequirement.adequateLighting,
        SetupEnvironmentRequirement.clearFloorArea,
      };
  static const Set<SetupEnvironmentRequirement> _wallEnvironment =
      <SetupEnvironmentRequirement>{
        ..._standingEnvironment,
        SetupEnvironmentRequirement.unobstructedWall,
      };
  static const Set<SetupEnvironmentRequirement> _raisedSurfaceEnvironment =
      <SetupEnvironmentRequirement>{
        SetupEnvironmentRequirement.stableCamera,
        SetupEnvironmentRequirement.adequateLighting,
        SetupEnvironmentRequirement.clearFloorArea,
        SetupEnvironmentRequirement.stableRaisedSurface,
      };

  static const Set<ExerciseAnalysisEngine> _rangeRepAnalysisEngines =
      <ExerciseAnalysisEngine>{
        ExerciseAnalysisEngine.rangeRep,
        ExerciseAnalysisEngine.tempo,
      };
  static const Set<ExerciseAnalysisEngine>
  _alternatingCapableRangeRepAnalysisEngines = <ExerciseAnalysisEngine>{
    ExerciseAnalysisEngine.rangeRep,
    ExerciseAnalysisEngine.alternatingRep,
    ExerciseAnalysisEngine.tempo,
    ExerciseAnalysisEngine.symmetry,
  };
  static const Set<ExerciseAnalysisEngine> _holdAnalysisEngines =
      <ExerciseAnalysisEngine>{
        ExerciseAnalysisEngine.hold,
        ExerciseAnalysisEngine.stability,
      };

  static const Set<ExerciseMetricId> _rangeRepMetricIds = <ExerciseMetricId>{
    ExerciseMetricId.repetitionCount,
    ExerciseMetricId.primaryMovement,
    ExerciseMetricId.form,
    ExerciseMetricId.rangeOfMotion,
    ExerciseMetricId.tempo,
  };
  static const Set<ExerciseMetricId> _alternatingRepMetricIds =
      <ExerciseMetricId>{
        ..._rangeRepMetricIds,
        ExerciseMetricId.symmetry,
        ExerciseMetricId.asymmetryScore,
      };
  static const Set<ExerciseMetricId> _holdMetricIds = <ExerciseMetricId>{
    ExerciseMetricId.holdDuration,
    ExerciseMetricId.form,
    ExerciseMetricId.stability,
  };

  static const Set<ExerciseFeedbackRuleId> _rangeRepFeedbackRuleIds =
      <ExerciseFeedbackRuleId>{
        ExerciseFeedbackRuleId.movementProgress,
        ExerciseFeedbackRuleId.formCorrection,
      };
  static const Set<ExerciseFeedbackRuleId>
  _rangeRepMovementOnlyFeedbackRuleIds = <ExerciseFeedbackRuleId>{
    ExerciseFeedbackRuleId.movementProgress,
  };
  static const Set<ExerciseFeedbackRuleId> _holdFeedbackRuleIds =
      <ExerciseFeedbackRuleId>{
        ExerciseFeedbackRuleId.holdProgress,
        ExerciseFeedbackRuleId.formCorrection,
      };

  static const Set<ExerciseSessionSummaryField> _rangeRepSummaryFields =
      <ExerciseSessionSummaryField>{
        ExerciseSessionSummaryField.repetitionCount,
        ExerciseSessionSummaryField.validRepetitions,
        ExerciseSessionSummaryField.invalidRepetitions,
        ExerciseSessionSummaryField.averageScore,
        ExerciseSessionSummaryField.averageTempo,
        ExerciseSessionSummaryField.fastestRep,
        ExerciseSessionSummaryField.slowestRep,
        ExerciseSessionSummaryField.tempoConsistency,
        ExerciseSessionSummaryField.sessionDuration,
      };
  static const Set<ExerciseSessionSummaryField> _alternatingRepSummaryFields =
      <ExerciseSessionSummaryField>{
        ..._rangeRepSummaryFields,
        ExerciseSessionSummaryField.asymmetryScore,
      };
  static const Set<ExerciseSessionSummaryField> _holdSummaryFields =
      <ExerciseSessionSummaryField>{
        ExerciseSessionSummaryField.holdDuration,
        ExerciseSessionSummaryField.averageScore,
        ExerciseSessionSummaryField.stabilityScore,
        ExerciseSessionSummaryField.sessionDuration,
      };

  static final List<ExerciseDefinition> _definitions = List.unmodifiable(
    <ExerciseDefinition>[
      ExerciseDefinition.supported(
        type: ExerciseType.squat,
        movementPattern: ExerciseMovementPattern.squat,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/squat.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _headToFeetCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 110.0,
          minDescentMillis: 300,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.plank,
        movementPattern: ExerciseMovementPattern.coreHold,
        trackingType: ExerciseTrackingType.hold,
        analysisEngines: _holdAnalysisEngines,
        metricIds: _holdMetricIds,
        feedbackRuleIds: _holdFeedbackRuleIds,
        sessionSummaryFields: _holdSummaryFields,
        engineKind: EngineKind.hold,
        configAssetPath: 'assets/config/exercises/plank.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.floorProneSupport,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        holdContract: HoldContracts.plankFamily,
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.hollowHold,
        movementPattern: ExerciseMovementPattern.coreHold,
        trackingType: ExerciseTrackingType.hold,
        analysisEngines: _holdAnalysisEngines,
        metricIds: _holdMetricIds,
        feedbackRuleIds: _holdFeedbackRuleIds,
        sessionSummaryFields: _holdSummaryFields,
        engineKind: EngineKind.hold,
        configAssetPath: 'assets/config/exercises/hollow_hold.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        holdContract: HoldContracts.hollowHold,
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.lunge,
        movementPattern: ExerciseMovementPattern.lunge,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _alternatingCapableRangeRepAnalysisEngines,
        metricIds: _alternatingRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _alternatingRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/stationary_lunge.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _headToAnklesCoverage,
          startPoseFamily: StartPoseFamily.splitStanceSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.stationaryLunge,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 20.0,
          minDescentMillis: 300,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.pushUp,
        movementPattern: ExerciseMovementPattern.horizontalPush,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/push_up.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.floorProneSupport,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.pushUp,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 110.0,
          minDescentMillis: 250,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.sitUp,
        movementPattern: ExerciseMovementPattern.trunkFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/sit_up.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _headToFeetCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.sitUp,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 110.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.crunch,
        movementPattern: ExerciseMovementPattern.trunkFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/crunch.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.crunch,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 12.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.reverseCrunch,
        movementPattern: ExerciseMovementPattern.trunkFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/reverse_crunch.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.reverseCrunch,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 20.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.bicepsCurl,
        movementPattern: ExerciseMovementPattern.elbowFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/biceps_curl.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.bicepsCurl,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 110.0,
          minDescentMillis: 250,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.lyingLegRaise,
        movementPattern: ExerciseMovementPattern.hipFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/lying_leg_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.lyingLegRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 30.0,
          minDescentMillis: 300,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.bentKneeLegRaise,
        movementPattern: ExerciseMovementPattern.hipFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/bent_knee_leg_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _floorLegCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.bentKneeLegRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
          minDescentMillis: 300,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.standingHamstringCurl,
        movementPattern: ExerciseMovementPattern.kneeFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/standing_hamstring_curl.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.standingHamstringCurl,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 40.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.standingHipAbduction,
        movementPattern: ExerciseMovementPattern.hipAbduction,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/standing_hip_abduction.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.standingHipAbduction,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.tricepsDip,
        movementPattern: ExerciseMovementPattern.elbowExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/triceps_dip.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _dipCoverage,
          startPoseFamily: StartPoseFamily.dipSupport,
          supportSurface: SetupSupportSurface.raisedSurface,
          cameraHeight: SetupCameraHeight.lowerBodyLevel,
          environmentRequirements: _raisedSurfaceEnvironment,
        ),
        rangeRepContract: RangeRepContracts.tricepsDip,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 30.0,
          minDescentMillis: 250,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.romanianDeadlift,
        movementPattern: ExerciseMovementPattern.hipHinge,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/romanian_deadlift.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.romanianDeadlift,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
          minDescentMillis: 350,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.goodMorning,
        movementPattern: ExerciseMovementPattern.hipHinge,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/good_morning.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.goodMorning,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
          minDescentMillis: 350,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.lateralRaise,
        movementPattern: ExerciseMovementPattern.shoulderAbduction,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/lateral_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.lateralRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 35.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.shoulderPress,
        movementPattern: ExerciseMovementPattern.verticalPush,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/shoulder_press.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyWithHeadCoverage,
          startPoseFamily: StartPoseFamily.standingElbowsBentFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingOverheadEnvironment,
        ),
        rangeRepContract: RangeRepContracts.shoulderPress,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),

      ExerciseDefinition.supported(
        type: ExerciseType.overheadTricepsExtension,
        movementPattern: ExerciseMovementPattern.elbowExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath:
            'assets/config/exercises/overhead_triceps_extension.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyWithHeadCoverage,
          startPoseFamily: StartPoseFamily.standingElbowsBentFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingOverheadEnvironment,
        ),
        rangeRepContract: RangeRepContracts.overheadTricepsExtension,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 40.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.uprightRow,
        movementPattern: ExerciseMovementPattern.shoulderAbduction,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/upright_row.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.uprightRow,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 30.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.calfRaise,
        movementPattern: ExerciseMovementPattern.anklePlantarFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/calf_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _lowerBodyCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.lowerBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.calfRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 10.0,
          minDescentMillis: 0,
          minAscentMillis: 0,
          minTotalRepMillis: 1500,
          allowLowConfidenceOnCoverageLoss: true,
          invalidateOnPersistentFormBreak: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.frontRaise,
        movementPattern: ExerciseMovementPattern.shoulderFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/front_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.frontRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 45.0,
          minDescentMillis: 250,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.gluteBridge,
        movementPattern: ExerciseMovementPattern.hipExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/glute_bridge.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.gluteBridge,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 10.0,
          minDescentMillis: 180,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.wallSit,
        movementPattern: ExerciseMovementPattern.squatHold,
        trackingType: ExerciseTrackingType.hold,
        analysisEngines: _holdAnalysisEngines,
        metricIds: _holdMetricIds,
        feedbackRuleIds: _holdFeedbackRuleIds,
        sessionSummaryFields: _holdSummaryFields,
        engineKind: EngineKind.hold,
        configAssetPath: 'assets/config/exercises/wall_sit.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _headToFeetCoverage,
          startPoseFamily: StartPoseFamily.wallSupportedHold,
          supportSurface: SetupSupportSurface.wall,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _wallEnvironment,
        ),
        holdContract: HoldContracts.wallSit,
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.sidePlank,
        movementPattern: ExerciseMovementPattern.sideCoreHold,
        trackingType: ExerciseTrackingType.hold,
        analysisEngines: _holdAnalysisEngines,
        metricIds: _holdMetricIds,
        feedbackRuleIds: _holdFeedbackRuleIds,
        sessionSummaryFields: _holdSummaryFields,
        engineKind: EngineKind.hold,
        configAssetPath: 'assets/config/exercises/side_plank.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.sideSupport,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        holdContract: HoldContracts.sidePlank,
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.jumpingJack,
        movementPattern: ExerciseMovementPattern.fullBodyAbduction,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/jumping_jack.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.dynamicBilateralNeutral,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.midBodyLevel,
          environmentRequirements: _standingOverheadEnvironment,
        ),
        rangeRepContract: RangeRepContracts.jumpingJack,
        analysisFrameInterval: const Duration(milliseconds: 50),
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 80.0,
          minDescentMillis: 150,
          minAscentMillis: 150,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.standingHipExtension,
        movementPattern: ExerciseMovementPattern.hipExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/standing_hip_extension.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.lowerBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.standingHipExtension,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 10.0,
          minDescentMillis: 0,
          minAscentMillis: 0,
          // Millisecond precision makes 1501 the first duration strictly
          // greater than the requested 1.5-second fast-rep boundary.
          minTotalRepMillis: 1501,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.standingKneeRaise,
        movementPattern: ExerciseMovementPattern.hipFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/standing_knee_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.lowerBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.standingKneeRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 40.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.standingStraightLegRaise,
        movementPattern: ExerciseMovementPattern.hipFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath:
            'assets/config/exercises/standing_straight_leg_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _sideChainCoverage,
          startPoseFamily: StartPoseFamily.standingNeutralSide,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.lowerBodyLevel,
          environmentRequirements: _standingEnvironment,
        ),
        rangeRepContract: RangeRepContracts.standingStraightLegRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 35.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.vUp,
        movementPattern: ExerciseMovementPattern.trunkFlexion,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/v_up.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _headToFeetCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.vUp,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 45.0,
          minDescentMillis: 300,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.frogPump,
        movementPattern: ExerciseMovementPattern.hipExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/frog_pump.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _floorLegCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.frogPump,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 10.0,
          minDescentMillis: 250,
          minAscentMillis: 250,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.lyingTricepsExtension,
        movementPattern: ExerciseMovementPattern.elbowExtension,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/lying_triceps_extension.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _fullBodyCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.lyingTricepsExtension,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 40.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.floorChestPress,
        movementPattern: ExerciseMovementPattern.horizontalPush,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepMovementOnlyFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/floor_chest_press.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.preferred,
            CameraView.front: CameraViewSupport.unsupported,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _floorPressCoverage,
          startPoseFamily: StartPoseFamily.floorSupine,
          supportSurface: SetupSupportSurface.floor,
          cameraHeight: SetupCameraHeight.floorLevel,
          environmentRequirements: _floorEnvironment,
        ),
        rangeRepContract: RangeRepContracts.floorChestPress,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 35.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
      ExerciseDefinition.supported(
        type: ExerciseType.yRaise,
        movementPattern: ExerciseMovementPattern.shoulderAbduction,
        trackingType: ExerciseTrackingType.repetitions,
        analysisEngines: _rangeRepAnalysisEngines,
        metricIds: _rangeRepMetricIds,
        feedbackRuleIds: _rangeRepFeedbackRuleIds,
        sessionSummaryFields: _rangeRepSummaryFields,
        engineKind: EngineKind.rangeRep,
        configAssetPath: 'assets/config/exercises/y_raise.json',
        cameraViewContract: CameraViewContract(
          views: const <CameraView, CameraViewSupport>{
            CameraView.side: CameraViewSupport.unsupported,
            CameraView.front: CameraViewSupport.preferred,
          },
        ),
        setupContract: ExerciseSetupContract(
          bodyCoverage: _upperBodyWithHeadCoverage,
          startPoseFamily: StartPoseFamily.standingArmsDownFront,
          supportSurface: SetupSupportSurface.none,
          cameraHeight: SetupCameraHeight.upperBodyLevel,
          environmentRequirements: _standingOverheadEnvironment,
        ),
        rangeRepContract: RangeRepContracts.yRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 60.0,
          minDescentMillis: 250,
          minAscentMillis: 300,
          allowLowConfidenceOnCoverageLoss: true,
        ),
      ),
    ],
  );

  static final Map<ExerciseType, ExerciseDefinition> _definitionsByType =
      _buildDefinitionsByType(_definitions);

  List<ExerciseDefinition> get definitions => _definitions;

  ExerciseDefinition definitionFor(ExerciseType type) {
    final definition = _definitionsByType[type];
    if (definition != null) {
      return definition;
    }

    throw StateError('Missing exercise definition for: $type');
  }

  ExerciseDefinition? definitionForIdOrNull(String id) {
    final type = ExerciseType.fromIdOrNull(id);
    if (type == null) {
      assert(false, 'Missing exercise definition for id: $id');
      return null;
    }

    return _definitionsByType[type];
  }

  static Map<ExerciseType, ExerciseDefinition> _buildDefinitionsByType(
    List<ExerciseDefinition> definitions,
  ) {
    final definitionsByType = <ExerciseType, ExerciseDefinition>{};
    for (final definition in definitions) {
      final previous = definitionsByType[definition.type];
      if (previous != null) {
        throw StateError(
          'Duplicate exercise definition registered for ${definition.type}.',
        );
      }
      definitionsByType[definition.type] = definition;
    }

    final missingTypes = ExerciseType.values
        .where((type) => !definitionsByType.containsKey(type))
        .map((type) => type.name)
        .toList(growable: false);
    if (missingTypes.isNotEmpty) {
      throw StateError(
        'Missing exercise definitions for: ${missingTypes.join(', ')}.',
      );
    }

    return Map.unmodifiable(definitionsByType);
  }
}
