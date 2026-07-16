import '../domain/analysis_engine.dart';
import '../domain/hold_analysis_engine.dart';
import '../domain/hold_engine.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_engine.dart';
import 'engine_kind.dart';

/// Creates the engine used by today's analysis pipeline.
///
/// Range-rep and hold are now real engine families. Alternating-rep stays
/// explicit until that family is implemented for real.
class AnalysisEngineFactory {
  const AnalysisEngineFactory();

  RangeRepAnalysisEngine createRangeRep({
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    DateTime Function()? now,
  }) {
    _validateRangeRepEngineContract(rangeRepContract);
    return RangeRepEngine(config: config, now: now);
  }

  HoldAnalysisEngine createHold({
    required ExerciseConfig config,
    required HoldContract holdContract,
    DateTime Function()? now,
  }) {
    switch (holdContract.family) {
      case HoldAnalysisFamily.plank:
        _validatePlankHoldEngineContract(holdContract, config);
        return HoldEngine(config: config, now: now);
    }
  }

  AnalysisEngine create({
    required EngineKind engineKind,
    required ExerciseConfig config,
    RangeRepContract? rangeRepContract,
    HoldContract? holdContract,
    DateTime Function()? now,
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
        return createRangeRep(
          config: config,
          rangeRepContract: requiredRangeRepContract,
          now: now,
        );
      case EngineKind.hold:
        final requiredHoldContract = holdContract;
        if (requiredHoldContract == null) {
          throw StateError(
            'Hold engine creation requires a non-null holdContract.',
          );
        }
        return createHold(
          config: config,
          holdContract: requiredHoldContract,
          now: now,
        );
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

  void _validatePlankHoldEngineContract(
    HoldContract contract,
    ExerciseConfig config,
  ) {
    for (final signal in const <HoldSignal>[
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
    ]) {
      if (!contract.supportsSignal(signal)) {
        throw StateError(
          'Current hold engine requires ${signal.name} in the hold contract.',
        );
      }
    }

    final holdSignals = config.holdSignals;
    if (holdSignals == null) {
      throw StateError(
        'Current hold engine requires holdSignals config for hold analysis.',
      );
    }

    for (final signal in const <HoldSignal>[
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
    ]) {
      if (holdSignals.definitionFor(signal) == null) {
        throw StateError(
          'Current hold engine missing ${signal.name} definition in '
          'holdSignals config.',
        );
      }
    }
  }
}
