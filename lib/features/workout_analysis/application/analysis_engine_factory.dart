import '../domain/analysis_engine.dart';
import '../domain/exercise_engine.dart';
import '../domain/models/exercise_config.dart';
import 'engine_kind.dart';

/// Creates the engine used by today's analysis pipeline.
///
/// Only the current range-rep implementation is real at the moment; the other
/// branches stay explicit so engineKind can already drive runtime creation
/// without pretending that multiple families are finished.
class AnalysisEngineFactory {
  const AnalysisEngineFactory();

  AnalysisEngine create({
    required EngineKind engineKind,
    required ExerciseConfig config,
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        return ExerciseEngine(config: config);
      case EngineKind.alternatingRep:
      case EngineKind.hold:
        assert(
          false,
          'EngineKind $engineKind is not implemented yet. Falling back to '
          'the current range-rep engine.',
        );
        return ExerciseEngine(config: config);
    }
  }
}
