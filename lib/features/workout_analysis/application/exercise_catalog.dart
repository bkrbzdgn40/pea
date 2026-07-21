import '../domain/models/camera_view_contract.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_validation_policy.dart';
import 'engine_kind.dart';
import 'exercise_definition.dart';
import 'exercise_definition_metadata.dart';
import 'exercise_metric_registry.dart';

/// Central exercise metadata source for analysis capability.
class ExerciseCatalog {
  const ExerciseCatalog();

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
      <ExerciseMetricId>{..._rangeRepMetricIds, ExerciseMetricId.symmetry};
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
        rangeRepContract: RangeRepContracts.sitUp,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 110.0,
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
        rangeRepContract: RangeRepContracts.lyingLegRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 30.0,
          minDescentMillis: 300,
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
        rangeRepContract: RangeRepContracts.romanianDeadlift,
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
        rangeRepContract: RangeRepContracts.shoulderPress,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 25.0,
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
        rangeRepContract: RangeRepContracts.calfRaise,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 15.0,
          minDescentMillis: 200,
          minAscentMillis: 200,
          allowLowConfidenceOnCoverageLoss: true,
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
        rangeRepContract: RangeRepContracts.gluteBridge,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 30.0,
          minDescentMillis: 300,
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
        rangeRepContract: RangeRepContracts.jumpingJack,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 80.0,
          minDescentMillis: 150,
          minAscentMillis: 150,
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
