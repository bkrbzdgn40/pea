import 'engine_kind.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';

/// In-memory exercise metadata that can later come from a JSON-backed source.
class ExerciseDefinition {
  const ExerciseDefinition.supported({
    required this.type,
    required this.id,
    required this.title,
    required this.engineKind,
    required this.configAssetPath,
    this.rangeRepContract,
  }) : isAnalysisSupported = true,
       activeAnalysisExercise = type;

  const ExerciseDefinition.unsupported({
    required this.type,
    required this.id,
    required this.title,
  }) : isAnalysisSupported = false,
       activeAnalysisExercise = null,
       engineKind = null,
       configAssetPath = null,
       rangeRepContract = null;

  final ExerciseType type;
  final String id;
  final String title;
  final bool isAnalysisSupported;
  final ExerciseType? activeAnalysisExercise;
  final EngineKind? engineKind;
  final String? configAssetPath;
  final RangeRepContract? rangeRepContract;

  ExerciseType get analysisExercise {
    final activeAnalysisExercise = this.activeAnalysisExercise;
    if (activeAnalysisExercise == null) {
      throw StateError('No analysis exercise registered for $type.');
    }

    return activeAnalysisExercise;
  }

  EngineKind get analysisEngineKind {
    final engineKind = this.engineKind;
    if (engineKind == null) {
      throw StateError('No analysis engine kind registered for $type.');
    }

    return engineKind;
  }

  String get analysisConfigAssetPath {
    final configAssetPath = this.configAssetPath;
    if (configAssetPath == null) {
      throw StateError('No analysis config asset path registered for $type.');
    }

    return configAssetPath;
  }

  RangeRepContract get analysisRangeRepContract {
    if (engineKind != EngineKind.rangeRep) {
      throw StateError('No range-rep contract registered for $type.');
    }

    final rangeRepContract = this.rangeRepContract;
    if (rangeRepContract == null) {
      throw StateError('No range-rep contract registered for $type.');
    }

    return rangeRepContract;
  }
}
