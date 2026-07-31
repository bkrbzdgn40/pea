import 'generic_rep_engine.dart';
import 'symmetry_engine.dart';
import 'tempo_engine.dart';

/// Canonical body sides tracked by [AlternatingRepEngine].
enum AlternatingRepSide { left, right }

extension AlternatingRepSideX on AlternatingRepSide {
  AlternatingRepSide get opposite => switch (this) {
    AlternatingRepSide.left => AlternatingRepSide.right,
    AlternatingRepSide.right => AlternatingRepSide.left,
  };
}

/// Immutable per-side session statistics produced by the alternating engine.
class AlternatingRepSideStats {
  const AlternatingRepSideStats({
    this.repCount = 0,
    this.averageRom = 0.0,
    this.averageTempo = Duration.zero,
    this.lastRom = 0.0,
    this.lastTempo = Duration.zero,
  });

  final int repCount;
  final double averageRom;
  final Duration averageTempo;
  final double lastRom;
  final Duration lastTempo;
}

/// A completed side-aware repetition.
class AlternatingRepCompletedRep {
  const AlternatingRepCompletedRep({
    required this.side,
    required this.sideRepIndex,
    required this.totalRepIndex,
    required this.rom,
    required this.tempo,
    this.tempoBreakdown,
    this.symmetryComparison,
  });

  final AlternatingRepSide side;
  final int sideRepIndex;
  final int totalRepIndex;
  final double rom;
  final Duration tempo;
  final TempoRepResult? tempoBreakdown;

  /// Pair-level symmetry facts when this completion closes a left/right pair.
  final SymmetryRepResult? symmetryComparison;
}

/// Per-frame result from [AlternatingRepEngine].
class AlternatingRepEngineFrameResult {
  const AlternatingRepEngineFrameResult({
    required this.activeSideBeforeUpdate,
    required this.activeSideAfterUpdate,
    this.repStartedSide,
    this.repAbortedSide,
    this.completedRep,
  });

  final AlternatingRepSide? activeSideBeforeUpdate;
  final AlternatingRepSide? activeSideAfterUpdate;
  final AlternatingRepSide? repStartedSide;
  final AlternatingRepSide? repAbortedSide;
  final AlternatingRepCompletedRep? completedRep;
}

/// Side-aware repetition engine built from two shared [GenericRepEngine]
/// lifecycles.
///
/// The engine owns side selection and session-level left/right statistics. It
/// deliberately stays independent from pose extraction, UI state, persistence,
/// and technique scoring. Callers provide already-extracted primary movement
/// metrics for either or both sides.
class AlternatingRepEngine
    implements TempoMetricsSource, SymmetryMetricsSource {
  AlternatingRepEngine({
    required GenericRepEngineConfig repConfig,
    TempoTowardPeakAction towardPeakAction = TempoTowardPeakAction.eccentric,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _leftEngine = GenericRepEngine(config: repConfig, now: () => _frameNow);
    _rightEngine = GenericRepEngine(config: repConfig, now: () => _frameNow);
    _leftTempoEngine = TempoEngine(towardPeakAction: towardPeakAction);
    _rightTempoEngine = TempoEngine(towardPeakAction: towardPeakAction);
  }

  final DateTime Function() _now;
  late final GenericRepEngine _leftEngine;
  late final GenericRepEngine _rightEngine;
  late final TempoEngine _leftTempoEngine;
  late final TempoEngine _rightTempoEngine;
  final TempoSessionAccumulator _tempoSessionAccumulator =
      TempoSessionAccumulator();
  final SymmetryEngine _symmetryEngine = SymmetryEngine();
  late DateTime _frameNow;

  AlternatingRepSide? activeSide;
  AlternatingRepSide? lastCompletedSide;
  int totalRepCount = 0;
  @override
  TempoRepResult? lastCompletedTempo;

  DateTime? _activeRepStartedAt;
  final _leftAccumulator = _AlternatingRepStatsAccumulator();
  final _rightAccumulator = _AlternatingRepStatsAccumulator();

  int get leftRepCount => _leftAccumulator.repCount;
  int get rightRepCount => _rightAccumulator.repCount;

  AlternatingRepSideStats get leftStats => _leftAccumulator.snapshot;
  AlternatingRepSideStats get rightStats => _rightAccumulator.snapshot;

  double get leftAverageRom => _leftAccumulator.averageRom;
  double get rightAverageRom => _rightAccumulator.averageRom;
  Duration get leftAverageTempo => _leftAccumulator.averageTempo;
  Duration get rightAverageTempo => _rightAccumulator.averageTempo;

  @override
  TempoSessionSummary get tempoSessionSummary =>
      _tempoSessionAccumulator.summary;
  TempoSessionSummary get leftTempoSessionSummary =>
      _leftTempoEngine.sessionSummary;
  TempoSessionSummary get rightTempoSessionSummary =>
      _rightTempoEngine.sessionSummary;

  @override
  SymmetryRepResult? get lastCompletedSymmetryPair =>
      _symmetryEngine.lastCompletedSymmetryPair;

  @override
  SymmetrySessionSummary get symmetrySessionSummary =>
      _symmetryEngine.symmetrySessionSummary;

  int get repCountDifference => symmetrySessionSummary.repCountDifference;
  double get averageRomDifference =>
      symmetrySessionSummary.averageRomDifference ?? 0.0;
  Duration get averageTempoDifference =>
      symmetrySessionSummary.averageTempoDifference ?? Duration.zero;

  /// Processes the latest left/right primary movement metrics.
  ///
  /// Either side may be omitted when its metric is temporarily unavailable.
  /// Once one side starts a repetition, only that side owns the active rep
  /// lifecycle until it completes or aborts. This prevents the opposite limb
  /// from stealing a rep midway through a movement.
  ///
  /// [observedAt] is the frame observation time. When omitted, direct callers
  /// retain the legacy processing-clock behavior.
  AlternatingRepEngineFrameResult update({
    double? leftPrimaryMetric,
    double? rightPrimaryMetric,
    DateTime? observedAt,
  }) {
    _frameNow = observedAt ?? _now();
    final activeSideBeforeUpdate = activeSide;

    if (activeSide != null) {
      return _updateActiveSide(
        activeSideBeforeUpdate: activeSideBeforeUpdate,
        leftPrimaryMetric: leftPrimaryMetric,
        rightPrimaryMetric: rightPrimaryMetric,
      );
    }

    final leftResult = leftPrimaryMetric == null
        ? null
        : _leftEngine.update(
            primaryMetric: leftPrimaryMetric,
            observedAt: _frameNow,
          );
    final rightResult = rightPrimaryMetric == null
        ? null
        : _rightEngine.update(
            primaryMetric: rightPrimaryMetric,
            observedAt: _frameNow,
          );

    if (leftResult != null) {
      _leftTempoEngine.process(leftResult);
    }
    if (rightResult != null) {
      _rightTempoEngine.process(rightResult);
    }

    final startedSide = _resolveStartedSide(
      leftResult: leftResult,
      rightResult: rightResult,
      leftPrimaryMetric: leftPrimaryMetric,
      rightPrimaryMetric: rightPrimaryMetric,
    );

    if (startedSide != null) {
      activeSide = startedSide;
      _activeRepStartedAt = _frameNow;
      _engineFor(startedSide.opposite).clearActiveRepContext();
      _tempoEngineFor(startedSide.opposite).interrupt();
    }

    return AlternatingRepEngineFrameResult(
      activeSideBeforeUpdate: activeSideBeforeUpdate,
      activeSideAfterUpdate: activeSide,
      repStartedSide: startedSide,
    );
  }

  /// Discards only in-progress side context while preserving completed stats.
  void interrupt() {
    _leftEngine.clearActiveRepContext();
    _rightEngine.clearActiveRepContext();
    _leftTempoEngine.interrupt();
    _rightTempoEngine.interrupt();
    activeSide = null;
    _activeRepStartedAt = null;
  }

  /// Resets both side lifecycles and all session-level statistics.
  void reset() {
    _leftEngine.reset();
    _rightEngine.reset();
    _leftTempoEngine.reset();
    _rightTempoEngine.reset();
    _tempoSessionAccumulator.reset();
    _symmetryEngine.reset();
    _leftAccumulator.reset();
    _rightAccumulator.reset();
    activeSide = null;
    lastCompletedSide = null;
    totalRepCount = 0;
    lastCompletedTempo = null;
    _activeRepStartedAt = null;
  }

  AlternatingRepEngineFrameResult _updateActiveSide({
    required AlternatingRepSide? activeSideBeforeUpdate,
    required double? leftPrimaryMetric,
    required double? rightPrimaryMetric,
  }) {
    final side = activeSide!;
    final metric = switch (side) {
      AlternatingRepSide.left => leftPrimaryMetric,
      AlternatingRepSide.right => rightPrimaryMetric,
    };

    if (metric == null) {
      return AlternatingRepEngineFrameResult(
        activeSideBeforeUpdate: activeSideBeforeUpdate,
        activeSideAfterUpdate: activeSide,
      );
    }

    final result = _engineFor(
      side,
    ).update(primaryMetric: metric, observedAt: _frameNow);
    final completedTempo = _tempoEngineFor(side).process(result);
    if (result.repAborted) {
      activeSide = null;
      _activeRepStartedAt = null;
      return AlternatingRepEngineFrameResult(
        activeSideBeforeUpdate: activeSideBeforeUpdate,
        activeSideAfterUpdate: null,
        repAbortedSide: side,
      );
    }

    final completedRep = result.completedRep;
    if (completedRep == null) {
      return AlternatingRepEngineFrameResult(
        activeSideBeforeUpdate: activeSideBeforeUpdate,
        activeSideAfterUpdate: activeSide,
      );
    }

    final startedAt = _activeRepStartedAt ?? _frameNow;
    var fallbackTempo = _frameNow.difference(startedAt);
    if (fallbackTempo.isNegative) {
      fallbackTempo = Duration.zero;
    }
    final tempo = completedTempo?.totalRepDuration ?? fallbackTempo;
    if (completedTempo != null) {
      lastCompletedTempo = completedTempo;
      _tempoSessionAccumulator.record(completedTempo);
    }

    final accumulator = _accumulatorFor(side);
    accumulator.record(rom: completedRep.rom, tempo: tempo);
    final symmetryComparison = _symmetryEngine.record(
      side: switch (side) {
        AlternatingRepSide.left => SymmetrySide.left,
        AlternatingRepSide.right => SymmetrySide.right,
      },
      sideRepIndex: accumulator.repCount,
      rom: completedRep.rom,
      tempo: tempo,
    );
    totalRepCount++;
    lastCompletedSide = side;

    final sideAwareCompletion = AlternatingRepCompletedRep(
      side: side,
      sideRepIndex: accumulator.repCount,
      totalRepIndex: totalRepCount,
      rom: completedRep.rom,
      tempo: tempo,
      tempoBreakdown: completedTempo,
      symmetryComparison: symmetryComparison,
    );

    activeSide = null;
    _activeRepStartedAt = null;

    return AlternatingRepEngineFrameResult(
      activeSideBeforeUpdate: activeSideBeforeUpdate,
      activeSideAfterUpdate: null,
      completedRep: sideAwareCompletion,
    );
  }

  AlternatingRepSide? _resolveStartedSide({
    required GenericRepEngineFrameResult? leftResult,
    required GenericRepEngineFrameResult? rightResult,
    required double? leftPrimaryMetric,
    required double? rightPrimaryMetric,
  }) {
    final leftStarted = leftResult?.repStarted ?? false;
    final rightStarted = rightResult?.repStarted ?? false;

    if (leftStarted && !rightStarted) {
      return AlternatingRepSide.left;
    }
    if (rightStarted && !leftStarted) {
      return AlternatingRepSide.right;
    }
    if (!leftStarted && !rightStarted) {
      return null;
    }

    final leftProgress = leftPrimaryMetric == null
        ? double.negativeInfinity
        : _progressFromNeutral(_leftEngine, leftPrimaryMetric);
    final rightProgress = rightPrimaryMetric == null
        ? double.negativeInfinity
        : _progressFromNeutral(_rightEngine, rightPrimaryMetric);

    // Deterministic tie-break keeps frame processing stable.
    return rightProgress > leftProgress
        ? AlternatingRepSide.right
        : AlternatingRepSide.left;
  }

  double _progressFromNeutral(GenericRepEngine engine, double value) {
    return switch (engine.config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        engine.config.neutralThreshold - value,
      GenericRepMetricDirection.increasingToPeak =>
        value - engine.config.neutralThreshold,
    };
  }

  GenericRepEngine _engineFor(AlternatingRepSide side) => switch (side) {
    AlternatingRepSide.left => _leftEngine,
    AlternatingRepSide.right => _rightEngine,
  };

  TempoEngine _tempoEngineFor(AlternatingRepSide side) => switch (side) {
    AlternatingRepSide.left => _leftTempoEngine,
    AlternatingRepSide.right => _rightTempoEngine,
  };

  _AlternatingRepStatsAccumulator _accumulatorFor(AlternatingRepSide side) =>
      switch (side) {
        AlternatingRepSide.left => _leftAccumulator,
        AlternatingRepSide.right => _rightAccumulator,
      };
}

class _AlternatingRepStatsAccumulator {
  int repCount = 0;
  double _totalRom = 0.0;
  int _totalTempoMillis = 0;
  double _lastRom = 0.0;
  Duration _lastTempo = Duration.zero;

  double get averageRom => repCount == 0 ? 0.0 : _totalRom / repCount;
  Duration get averageTempo => repCount == 0
      ? Duration.zero
      : Duration(milliseconds: _totalTempoMillis ~/ repCount);

  AlternatingRepSideStats get snapshot => AlternatingRepSideStats(
    repCount: repCount,
    averageRom: averageRom,
    averageTempo: averageTempo,
    lastRom: _lastRom,
    lastTempo: _lastTempo,
  );

  void record({required double rom, required Duration tempo}) {
    repCount++;
    _totalRom += rom;
    _totalTempoMillis += tempo.inMilliseconds;
    _lastRom = rom;
    _lastTempo = tempo;
  }

  void reset() {
    repCount = 0;
    _totalRom = 0.0;
    _totalTempoMillis = 0;
    _lastRom = 0.0;
    _lastTempo = Duration.zero;
  }
}
