import 'engine_kind.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';

/// In-memory exercise metadata that can later come from a JSON-backed source.
class ExerciseDefinition {
  const ExerciseDefinition.supported({
    required this.type,
    required this.engineKind,
    required this.configAssetPath,
    this.rangeRepContract,
    this.holdContract,
  }) : isAnalysisSupported = true,
       assert(engineKind != EngineKind.rangeRep || rangeRepContract != null),
       assert(engineKind != EngineKind.hold || holdContract != null),
       assert(engineKind != EngineKind.rangeRep || holdContract == null),
       assert(engineKind != EngineKind.hold || rangeRepContract == null);

  const ExerciseDefinition.unsupported({required this.type})
    : isAnalysisSupported = false,
      engineKind = null,
      configAssetPath = null,
      rangeRepContract = null,
      holdContract = null;

  final ExerciseType type;
  final bool isAnalysisSupported;
  final EngineKind? engineKind;
  final String? configAssetPath;
  final RangeRepContract? rangeRepContract;
  final HoldContract? holdContract;

  String get id => type.id;

  String get title => type.title;

  ExerciseType get analysisExercise {
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
    if (engineKind == null || configAssetPath == null) {
      throw StateError('Incomplete analysis definition registered for $type.');
    }

    switch (engineKind) {
      case EngineKind.rangeRep:
        if (rangeRepContract == null) {
          throw StateError('No range-rep contract registered for $type.');
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
        return;
      case EngineKind.alternatingRep:
        if (rangeRepContract != null || holdContract != null) {
          throw StateError(
            'Alternating-rep definition for $type cannot declare analysis '
            'contracts.',
          );
        }
        return;
    }
  }
}
