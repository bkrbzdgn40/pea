import '../domain/models/exercise_config.dart';
import '../domain/models/exercise_type.dart';
import 'exercise_catalog.dart';

abstract class ExerciseConfigSource {
  Future<ExerciseConfig> loadConfig(String assetPath);
}

/// Resolves the analysis config for the active exercise.
class ExerciseConfigResolver {
  const ExerciseConfigResolver({
    required ExerciseConfigSource source,
    ExerciseCatalog catalog = const ExerciseCatalog(),
  }) : _source = source,
       _catalog = catalog;

  final ExerciseConfigSource _source;
  final ExerciseCatalog _catalog;

  Future<ExerciseConfig> resolve(ExerciseType activeExercise) {
    final definition = _catalog.definitionFor(activeExercise);
    final fallbackAssetPath = _catalog
        .definitionFor(ExerciseType.squat)
        .configAssetPath;
    final assetPath = definition.configAssetPath ?? fallbackAssetPath;

    assert(
      definition.isAnalysisSupported,
      'Unsupported active analysis exercise reached config resolution: '
      '$activeExercise',
    );

    if (assetPath == null) {
      throw StateError(
        'No exercise config asset path registered for $activeExercise.',
      );
    }

    return _source.loadConfig(assetPath);
  }
}
