import '../domain/analysis_engine.dart';
import '../domain/exercise_engine.dart';
import '../domain/hold_engine.dart';
import '../domain/models/exercise_config.dart';
import 'engine_kind.dart';

/// Creates the engine used by today's analysis pipeline.
///
/// Range-rep and hold are now real engine families. Alternating-rep stays
/// explicit until that family is implemented for real.
class AnalysisEngineFactory {
  const AnalysisEngineFactory();

  AnalysisEngine create({
    required EngineKind engineKind,
    required ExerciseConfig config,
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        return ExerciseEngine(config: config);
      case EngineKind.hold:
        return HoldEngine(config: config);
      case EngineKind.alternatingRep:
        assert(
          false,
          'EngineKind $engineKind is not implemented yet. Falling back to '
          'the current range-rep engine.',
        );
        return ExerciseEngine(config: config);
    }
  }
}
