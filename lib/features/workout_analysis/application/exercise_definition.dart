import '../domain/models/camera_view_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_validation_policy.dart';
import 'engine_kind.dart';
import 'exercise_definition_metadata.dart';

/// Central, in-memory exercise contract.
///
/// Runtime analysis details still live in the existing engine/config contracts,
/// while product-facing capabilities are declared here so callers do not need
/// to rediscover exercise behavior through scattered switch statements.
class ExerciseDefinition {
  ExerciseDefinition.supported({
    required this.type,
    required this.movementPattern,
    required this.trackingType,
    required this.engineKind,
    required this.configAssetPath,
    required CameraViewContract cameraViewContract,
    required Set<ExerciseAnalysisEngine> analysisEngines,
    required Set<ExerciseMetricId> metricIds,
    required Set<ExerciseFeedbackRuleId> feedbackRuleIds,
    required Set<ExerciseSessionSummaryField> sessionSummaryFields,
    this.rangeRepContract,
    this.rangeRepValidationConfig,
    this.holdContract,
  }) : isAnalysisSupported = true,
       // ignore: prefer_initializing_formals
       cameraViewContract = cameraViewContract,
       analysisEngines = Set<ExerciseAnalysisEngine>.unmodifiable(
         analysisEngines,
       ),
       metricIds = Set<ExerciseMetricId>.unmodifiable(metricIds),
       feedbackRuleIds = Set<ExerciseFeedbackRuleId>.unmodifiable(
         feedbackRuleIds,
       ),
       sessionSummaryFields = Set<ExerciseSessionSummaryField>.unmodifiable(
         sessionSummaryFields,
       ),
       assert(analysisEngines.isNotEmpty),
       assert(metricIds.isNotEmpty),
       assert(feedbackRuleIds.isNotEmpty),
       assert(sessionSummaryFields.isNotEmpty),
       assert(
         engineKind != EngineKind.rangeRep ||
             analysisEngines.contains(ExerciseAnalysisEngine.rangeRep),
       ),
       assert(
         engineKind != EngineKind.alternatingRep ||
             analysisEngines.contains(ExerciseAnalysisEngine.alternatingRep),
       ),
       assert(
         engineKind != EngineKind.hold ||
             analysisEngines.contains(ExerciseAnalysisEngine.hold),
       ),
       assert(
         trackingType != ExerciseTrackingType.repetitions ||
             engineKind != EngineKind.hold,
       ),
       assert(
         trackingType != ExerciseTrackingType.hold ||
             engineKind == EngineKind.hold,
       ),
       assert(engineKind != EngineKind.rangeRep || rangeRepContract != null),
       assert(
         engineKind != EngineKind.rangeRep || rangeRepValidationConfig != null,
       ),
       assert(engineKind != EngineKind.hold || holdContract != null),
       assert(engineKind != EngineKind.rangeRep || holdContract == null),
       assert(engineKind != EngineKind.hold || rangeRepContract == null),
       assert(
         engineKind == EngineKind.rangeRep || rangeRepValidationConfig == null,
       );

  const ExerciseDefinition.unsupported({
    required this.type,
    required this.movementPattern,
    required this.trackingType,
  }) : isAnalysisSupported = false,
       engineKind = null,
       configAssetPath = null,
       cameraViewContract = null,
       analysisEngines = const <ExerciseAnalysisEngine>{},
       metricIds = const <ExerciseMetricId>{},
       feedbackRuleIds = const <ExerciseFeedbackRuleId>{},
       sessionSummaryFields = const <ExerciseSessionSummaryField>{},
       rangeRepContract = null,
       rangeRepValidationConfig = null,
       holdContract = null;

  final ExerciseType type;
  final ExerciseMovementPattern movementPattern;
  final ExerciseTrackingType trackingType;
  final bool isAnalysisSupported;
  final EngineKind? engineKind;
  final String? configAssetPath;
  final CameraViewContract? cameraViewContract;
  final Set<ExerciseAnalysisEngine> analysisEngines;
  final Set<ExerciseMetricId> metricIds;
  final Set<ExerciseFeedbackRuleId> feedbackRuleIds;
  final Set<ExerciseSessionSummaryField> sessionSummaryFields;
  final RangeRepContract? rangeRepContract;
  final RangeRepValidationConfig? rangeRepValidationConfig;
  final HoldContract? holdContract;

  String get id => type.id;

  String get displayName => type.title;

  String get title => displayName;

  bool usesAnalysisEngine(ExerciseAnalysisEngine engine) {
    return analysisEngines.contains(engine);
  }

  bool declaresMetric(ExerciseMetricId metricId) {
    return metricIds.contains(metricId);
  }

  bool declaresFeedbackRule(ExerciseFeedbackRuleId feedbackRuleId) {
    return feedbackRuleIds.contains(feedbackRuleId);
  }

  bool includesSummaryField(ExerciseSessionSummaryField field) {
    return sessionSummaryFields.contains(field);
  }

  ExerciseType get analysisExercise {
    if (!isAnalysisSupported) {
      throw StateError('No analysis exercise registered for $type.');
    }

    _ensureAnalysisDefinitionConsistency();
    return type;
  }

  EngineKind get analysisEngineKind {
    _ensureAnalysisDefinitionConsistency();
    final engineKind = this.engineKind;
    if (engineKind == null) {
      throw StateError('No analysis engine kind registered for $type.');
    }

    return engineKind;
  }

  String get analysisConfigAssetPath {
    _ensureAnalysisDefinitionConsistency();
    final configAssetPath = this.configAssetPath;
    if (configAssetPath == null) {
      throw StateError('No analysis config asset path registered for $type.');
    }

    return configAssetPath;
  }

  CameraViewContract get analysisCameraViewContract {
    _ensureAnalysisDefinitionConsistency();
    final cameraViewContract = this.cameraViewContract;
    if (cameraViewContract == null) {
      throw StateError('No camera-view contract registered for $type.');
    }

    return cameraViewContract;
  }

  RangeRepContract get analysisRangeRepContract {
    _ensureAnalysisDefinitionConsistency();
    if (engineKind != EngineKind.rangeRep) {
      throw StateError('No range-rep contract registered for $type.');
    }

    final rangeRepContract = this.rangeRepContract;
    if (rangeRepContract == null) {
      throw StateError('No range-rep contract registered for $type.');
    }

    return rangeRepContract;
  }

  RangeRepValidationConfig get analysisRangeRepValidationConfig {
    _ensureAnalysisDefinitionConsistency();
    if (engineKind != EngineKind.rangeRep) {
      throw StateError('No range-rep validation config registered for $type.');
    }

    final rangeRepValidationConfig = this.rangeRepValidationConfig;
    if (rangeRepValidationConfig == null) {
      throw StateError('No range-rep validation config registered for $type.');
    }

    return rangeRepValidationConfig;
  }

  HoldContract get analysisHoldContract {
    _ensureAnalysisDefinitionConsistency();
    if (engineKind != EngineKind.hold) {
      throw StateError('No hold contract registered for $type.');
    }

    final holdContract = this.holdContract;
    if (holdContract == null) {
      throw StateError('No hold contract registered for $type.');
    }

    return holdContract;
  }

  void _ensureAnalysisDefinitionConsistency() {
    if (!isAnalysisSupported) {
      return;
    }

    final engineKind = this.engineKind;
    if (engineKind == null ||
        configAssetPath == null ||
        cameraViewContract == null) {
      throw StateError('Incomplete analysis definition registered for $type.');
    }

    if (analysisEngines.isEmpty ||
        metricIds.isEmpty ||
        feedbackRuleIds.isEmpty ||
        sessionSummaryFields.isEmpty) {
      throw StateError(
        'Incomplete capability definition registered for $type.',
      );
    }

    switch (engineKind) {
      case EngineKind.rangeRep:
        if (!analysisEngines.contains(ExerciseAnalysisEngine.rangeRep)) {
          throw StateError(
            'Range-rep definition for $type must declare the range-rep '
            'analysis engine.',
          );
        }
        if (trackingType != ExerciseTrackingType.repetitions) {
          throw StateError(
            'Range-rep definition for $type must use repetition tracking.',
          );
        }
        if (rangeRepContract == null) {
          throw StateError('No range-rep contract registered for $type.');
        }
        if (rangeRepValidationConfig == null) {
          throw StateError(
            'No range-rep validation config registered for $type.',
          );
        }
        if (holdContract != null) {
          throw StateError(
            'Range-rep definition for $type cannot also declare a hold '
            'contract.',
          );
        }
        return;
      case EngineKind.hold:
        if (!analysisEngines.contains(ExerciseAnalysisEngine.hold)) {
          throw StateError(
            'Hold definition for $type must declare the hold analysis engine.',
          );
        }
        if (trackingType != ExerciseTrackingType.hold) {
          throw StateError('Hold definition for $type must use hold tracking.');
        }
        if (holdContract == null) {
          throw StateError('No hold contract registered for $type.');
        }
        if (rangeRepContract != null) {
          throw StateError(
            'Hold definition for $type cannot also declare a range-rep '
            'contract.',
          );
        }
        if (rangeRepValidationConfig != null) {
          throw StateError(
            'Hold definition for $type cannot also declare a range-rep '
            'validation config.',
          );
        }
        return;
      case EngineKind.alternatingRep:
        if (!analysisEngines.contains(ExerciseAnalysisEngine.alternatingRep)) {
          throw StateError(
            'Alternating-rep definition for $type must declare the '
            'alternating-rep analysis engine.',
          );
        }
        if (trackingType != ExerciseTrackingType.repetitions) {
          throw StateError(
            'Alternating-rep definition for $type must use repetition '
            'tracking.',
          );
        }
        if (rangeRepContract != null ||
            rangeRepValidationConfig != null ||
            holdContract != null) {
          throw StateError(
            'Alternating-rep definition for $type cannot declare analysis '
            'contracts or range-rep validation config.',
          );
        }
        return;
    }
  }
}
