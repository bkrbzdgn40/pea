import '../domain/analysis_engine.dart';
import '../domain/range_rep_engine.dart';
import '../domain/hold_engine.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
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
    RangeRepContract? rangeRepContract,
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        final requiredRangeRepContract = rangeRepContract;
        if (requiredRangeRepContract == null) {
          throw StateError(
            'Range-rep engine creation requires a non-null '
            'rangeRepContract.',
          );
        }
        _validateRangeRepEngineContract(requiredRangeRepContract);
        return RangeRepEngine(config: config);
      case EngineKind.hold:
        return HoldEngine(config: config);
      case EngineKind.alternatingRep:
        throw StateError(
          'EngineKind $engineKind is not implemented for analysis engine '
          'creation.',
        );
    }
  }

  void _validateRangeRepEngineContract(RangeRepContract contract) {
    if (!contract.supportsPhase(RangeRepPhase.descending) ||
        !contract.supportsPhase(RangeRepPhase.peak) ||
        !contract.supportsPhase(RangeRepPhase.ascending)) {
      throw StateError(
        'Current range-rep engine requires descending, peak, and ascending '
        'phases in the range-rep contract.',
      );
    }

    if (!contract.supportsSignal(RangeRepSignal.primaryMetric) ||
        !contract.supportsSignal(RangeRepSignal.formMetric)) {
      throw StateError(
        'Current range-rep engine requires primaryMetric and formMetric '
        'signals in the range-rep contract.',
      );
    }
  }
}
