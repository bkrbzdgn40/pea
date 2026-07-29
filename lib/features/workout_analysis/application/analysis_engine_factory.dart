import '../domain/analysis_engine.dart';
import '../domain/alternating_rep_engine.dart';
import '../domain/generic_rep_engine.dart';
import '../domain/hold_form_policy.dart';
import '../domain/hold_analysis_engine.dart';
import '../domain/hold_engine.dart';
import '../domain/hollow_hold_posture_policy.dart';
import '../domain/hold_posture_policy.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_engine.dart';
import '../domain/side_plank_posture_policy.dart';
import '../domain/tempo_engine.dart';
import '../domain/wall_sit_posture_policy.dart';
import 'engine_kind.dart';

/// Creates the engine used by today's analysis pipeline.
///
/// Range-rep, alternating-rep, and hold have dedicated typed creation paths.
/// The generic [create] surface remains limited to single-frame engine families;
/// alternating-rep uses [createAlternatingRep] because it consumes both sides.
class AnalysisEngineFactory {
  const AnalysisEngineFactory();

  RangeRepAnalysisEngine createRangeRep({
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    DateTime Function()? now,
  }) {
    _validateRangeRepEngineContract(rangeRepContract, config);
    return RangeRepEngine(
      config: config,
      primaryMetricDirection: rangeRepContract.primaryMetricDirection,
      towardPeakMuscleAction: rangeRepContract.towardPeakMuscleAction,
      activeEntryMargin: rangeRepContract.activeEntryMargin,
      peakEntryMargin: rangeRepContract.peakEntryMargin,
      peakExitMargin: rangeRepContract.peakExitMargin,
      retainPeakEvidenceAcrossActiveTransition:
          rangeRepContract.retainPeakEvidenceAcrossActiveTransition,
      allowSparseCycleRecovery: rangeRepContract.allowSparseCycleRecovery,
      initialNeutralConfirmationDuration:
          rangeRepContract.initialNeutralConfirmationDuration,
      neutralBaselineWindow: rangeRepContract.neutralBaselineWindow,
      neutralBaselineThresholdMargin:
          rangeRepContract.neutralBaselineThresholdMargin,
      now: now,
    );
  }

  AlternatingRepEngine createAlternatingRep({
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    double minimumRom = 0.0,
    DateTime Function()? now,
  }) {
    _validateRangeRepEngineContract(rangeRepContract, config);
    return AlternatingRepEngine(
      repConfig: GenericRepEngineConfig(
        neutralThreshold: config.thresholdNeutral,
        activeThreshold: config.thresholdActive,
        peakThreshold: config.thresholdPeak,
        direction: switch (rangeRepContract.primaryMetricDirection) {
          RangeRepPrimaryMetricDirection.decreasingToPeak =>
            GenericRepMetricDirection.decreasingToPeak,
          RangeRepPrimaryMetricDirection.increasingToPeak =>
            GenericRepMetricDirection.increasingToPeak,
        },
        minimumRom: minimumRom,
      ),
      towardPeakAction: switch (rangeRepContract.towardPeakMuscleAction) {
        RangeRepTowardPeakMuscleAction.eccentric =>
          TempoTowardPeakAction.eccentric,
        RangeRepTowardPeakMuscleAction.concentric =>
          TempoTowardPeakAction.concentric,
      },
      now: now,
    );
  }

  HoldAnalysisEngine createHold({
    required ExerciseConfig config,
    required HoldContract holdContract,
    DateTime Function()? now,
  }) {
    switch (holdContract.family) {
      case HoldAnalysisFamily.plank:
        _validatePlankHoldEngineContract(holdContract, config);
        return HoldEngine(
          posturePolicy: _createPlankPosturePolicy(config),
          stabilitySignals: holdContract.requiredSignals,
          now: now,
        );
      case HoldAnalysisFamily.hollowHold:
        _validateHollowHoldEngineContract(holdContract, config);
        return HoldEngine(
          posturePolicy: _createHollowHoldPosturePolicy(config, holdContract),
          stabilitySignals: holdContract.requiredSignals,
          now: now,
        );
      case HoldAnalysisFamily.wallSit:
        _validateWallSitHoldEngineContract(holdContract, config);
        return HoldEngine(
          posturePolicy: _createWallSitPosturePolicy(config),
          stabilitySignals: holdContract.requiredSignals,
          now: now,
        );
      case HoldAnalysisFamily.sidePlank:
        _validatePlankHoldEngineContract(holdContract, config);
        return HoldEngine(
          posturePolicy: SidePlankPosturePolicy(
            config: config.resolvedHoldPosture,
          ),
          stabilitySignals: holdContract.requiredSignals,
          now: now,
        );
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
          'EngineKind $engineKind requires the side-aware '
          'createAlternatingRep(...) factory path.',
        );
    }
  }

  void _validateRangeRepEngineContract(
    RangeRepContract contract,
    ExerciseConfig config,
  ) {
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

    switch (contract.primaryMetricDirection) {
      case RangeRepPrimaryMetricDirection.decreasingToPeak:
        if (!(config.thresholdNeutral > config.thresholdActive &&
            config.thresholdActive > config.thresholdPeak)) {
          throw StateError(
            'decreasingToPeak range-rep config requires '
            'thresholdNeutral > thresholdActive > thresholdPeak.',
          );
        }
        break;
      case RangeRepPrimaryMetricDirection.increasingToPeak:
        if (!(config.thresholdNeutral < config.thresholdActive &&
            config.thresholdActive < config.thresholdPeak)) {
          throw StateError(
            'increasingToPeak range-rep config requires '
            'thresholdNeutral < thresholdActive < thresholdPeak.',
          );
        }
        break;
    }
  }

  void _validatePlankHoldEngineContract(
    HoldContract contract,
    ExerciseConfig config,
  ) {
    _validateRequiredHoldSignals(
      contract: contract,
      config: config,
      requiredSignals: const <HoldSignal>[
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
      ],
    );
  }

  void _validateHollowHoldEngineContract(
    HoldContract contract,
    ExerciseConfig config,
  ) {
    _validateRequiredHoldSignals(
      contract: contract,
      config: config,
      requiredSignals: contract.requiredSignals,
    );

    if (config.hollowHoldPosture == null) {
      throw StateError(
        'Current hold engine requires hollowHoldPosture config for hold '
        'analysis.',
      );
    }
  }

  void _validateWallSitHoldEngineContract(
    HoldContract contract,
    ExerciseConfig config,
  ) {
    _validateRequiredHoldSignals(
      contract: contract,
      config: config,
      requiredSignals: const <HoldSignal>[
        HoldSignal.kneeFlexion,
        HoldSignal.hipFlexion,
        HoldSignal.torsoAlignment,
      ],
    );

    if (config.wallSitPosture == null) {
      throw StateError(
        'Current hold engine requires wallSitPosture config for wall-sit '
        'analysis.',
      );
    }
  }

  void _validateRequiredHoldSignals({
    required HoldContract contract,
    required ExerciseConfig config,
    required Iterable<HoldSignal> requiredSignals,
  }) {
    for (final signal in requiredSignals) {
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

    for (final signal in requiredSignals) {
      if (holdSignals.definitionFor(signal) == null) {
        throw StateError(
          'Current hold engine missing ${signal.name} definition in '
          'holdSignals config.',
        );
      }
    }
  }

  HoldFormPolicy _createPlankPosturePolicy(ExerciseConfig config) {
    return HoldPosturePolicy(config: config.resolvedHoldPosture);
  }

  HoldFormPolicy _createHollowHoldPosturePolicy(
    ExerciseConfig config,
    HoldContract holdContract,
  ) {
    final hollowHoldPosture = config.hollowHoldPosture;
    if (hollowHoldPosture == null) {
      throw StateError(
        'Current hold engine requires hollowHoldPosture config for hold '
        'analysis.',
      );
    }

    final variationContract = holdContract.hollowHoldVariation;
    if (variationContract == null) {
      throw StateError(
        'Hollow Hold analysis requires an explicit variation contract.',
      );
    }

    return HollowHoldPosturePolicy(
      config: hollowHoldPosture,
      variationContract: variationContract,
    );
  }

  HoldFormPolicy _createWallSitPosturePolicy(ExerciseConfig config) {
    final wallSitPosture = config.wallSitPosture;
    if (wallSitPosture == null) {
      throw StateError(
        'Current hold engine requires wallSitPosture config for wall-sit '
        'analysis.',
      );
    }

    return WallSitPosturePolicy(config: wallSitPosture);
  }
}
