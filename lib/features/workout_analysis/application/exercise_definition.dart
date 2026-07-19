import 'engine_kind.dart';
import '../domain/models/camera_view_contract.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_validation_policy.dart';

/// In-memory exercise metadata that can later come from a JSON-backed source.
class ExerciseDefinition {
  const ExerciseDefinition.supported({
    required this.type,
    required this.engineKind,
    required this.configAssetPath,
    required this.cameraViewContract,
    this.rangeRepContract,
    this.rangeRepValidationConfig,
    this.holdContract,
  }) : isAnalysisSupported = true,
       assert(cameraViewContract != null),
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

  const ExerciseDefinition.unsupported({required this.type})
    : isAnalysisSupported = false,
      engineKind = null,
      configAssetPath = null,
      cameraViewContract = null,
      rangeRepContract = null,
      rangeRepValidationConfig = null,
      holdContract = null;

  final ExerciseType type;
  final bool isAnalysisSupported;
  final EngineKind? engineKind;
  final String? configAssetPath;
  final CameraViewContract? cameraViewContract;
  final RangeRepContract? rangeRepContract;
  final RangeRepValidationConfig? rangeRepValidationConfig;
  final HoldContract? holdContract;

  String get id => type.id;

  String get title => type.title;

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

    switch (engineKind) {
      case EngineKind.rangeRep:
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
