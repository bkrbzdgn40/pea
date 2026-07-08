import 'engine_kind.dart';
import '../domain/models/exercise_type.dart';

/// In-memory exercise metadata that can later come from a JSON-backed source.
class ExerciseDefinition {
  const ExerciseDefinition.supported({
    required this.type,
    required this.id,
    required this.title,
    required this.engineKind,
    required this.configAssetPath,
  }) : isAnalysisSupported = true,
       activeAnalysisExercise = type;

  const ExerciseDefinition.unsupported({
    required this.type,
    required this.id,
    required this.title,
  }) : isAnalysisSupported = false,
       activeAnalysisExercise = null,
       engineKind = null,
       configAssetPath = null;

  final ExerciseType type;
  final String id;
  final String title;
  final bool isAnalysisSupported;
  final ExerciseType? activeAnalysisExercise;
  final EngineKind? engineKind;
  final String? configAssetPath;

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
}
