import 'dart:math' as math;

/// Canonical side identity used by [SymmetryEngine].
enum SymmetrySide { left, right }

/// Symmetry facts for one matched left/right repetition pair.
class SymmetryRepResult {
  const SymmetryRepResult({
    required this.pairIndex,
    required this.leftRom,
    required this.rightRom,
    required this.romDifference,
    required this.romSymmetryScore,
    required this.leftTempo,
    required this.rightTempo,
    required this.tempoDifference,
    required this.tempoSymmetryScore,
    required this.overallSymmetryScore,
  });

  final int pairIndex;
  final double leftRom;
  final double rightRom;
  final double romDifference;
  final double romSymmetryScore;
  final Duration leftTempo;
  final Duration rightTempo;
  final Duration tempoDifference;
  final double tempoSymmetryScore;
  final double overallSymmetryScore;

  double get romAsymmetryScore => 100 - romSymmetryScore;
  double get tempoAsymmetryScore => 100 - tempoSymmetryScore;
  double get overallAsymmetryScore => 100 - overallSymmetryScore;
}

/// Session-level left/right symmetry summary.
///
/// Nullable score fields mean the comparison is not yet measurable. Missing
/// side data is deliberately not converted to a fake zero-valued ROM or tempo
/// score.
class SymmetrySessionSummary {
  const SymmetrySessionSummary({
    required this.leftRepCount,
    required this.rightRepCount,
    required this.pairedRepCount,
    required this.repCountDifference,
    required this.repCountSymmetryScore,
    required this.leftAverageRom,
    required this.rightAverageRom,
    required this.averageRomDifference,
    required this.romSymmetryScore,
    required this.leftAverageTempo,
    required this.rightAverageTempo,
    required this.averageTempoDifference,
    required this.tempoSymmetryScore,
    required this.overallSymmetryScore,
  });

  static const empty = SymmetrySessionSummary(
    leftRepCount: 0,
    rightRepCount: 0,
    pairedRepCount: 0,
    repCountDifference: 0,
    repCountSymmetryScore: null,
    leftAverageRom: null,
    rightAverageRom: null,
    averageRomDifference: null,
    romSymmetryScore: null,
    leftAverageTempo: null,
    rightAverageTempo: null,
    averageTempoDifference: null,
    tempoSymmetryScore: null,
    overallSymmetryScore: null,
  );

  final int leftRepCount;
  final int rightRepCount;
  final int pairedRepCount;
  final int repCountDifference;
  final double? repCountSymmetryScore;

  final double? leftAverageRom;
  final double? rightAverageRom;
  final double? averageRomDifference;
  final double? romSymmetryScore;

  final Duration? leftAverageTempo;
  final Duration? rightAverageTempo;
  final Duration? averageTempoDifference;
  final double? tempoSymmetryScore;

  /// 0-100 mean of rep-count, ROM, and tempo symmetry once both sides have
  /// measurable repetition data. Null until a bilateral comparison is valid.
  final double? overallSymmetryScore;

  double? get repCountAsymmetryScore =>
      repCountSymmetryScore == null ? null : 100 - repCountSymmetryScore!;
  double? get romAsymmetryScore =>
      romSymmetryScore == null ? null : 100 - romSymmetryScore!;
  double? get tempoAsymmetryScore =>
      tempoSymmetryScore == null ? null : 100 - tempoSymmetryScore!;
  double? get overallAsymmetryScore =>
      overallSymmetryScore == null ? null : 100 - overallSymmetryScore!;
}

/// Read-only symmetry capability exposed by bilateral engines.
abstract interface class SymmetryMetricsSource {
  SymmetryRepResult? get lastCompletedSymmetryPair;

  SymmetrySessionSummary get symmetrySessionSummary;
}

/// Central bilateral symmetry engine.
///
/// It accepts completed side-aware repetitions, matches the Nth left rep with
/// the Nth right rep, and owns both pair-level and session-level comparisons.
/// It deliberately knows nothing about pose landmarks, repetition detection,
/// technique scoring, feedback, persistence, or presentation.
class SymmetryEngine implements SymmetryMetricsSource {
  final _leftAccumulator = _SymmetrySideAccumulator();
  final _rightAccumulator = _SymmetrySideAccumulator();
  final Map<int, _SymmetryRepSample> _leftSamples = <int, _SymmetryRepSample>{};
  final Map<int, _SymmetryRepSample> _rightSamples =
      <int, _SymmetryRepSample>{};
  final Set<int> _completedPairIndices = <int>{};

  @override
  SymmetryRepResult? lastCompletedSymmetryPair;

  int get leftRepCount => _leftAccumulator.repCount;
  int get rightRepCount => _rightAccumulator.repCount;
  int get pairedRepCount => _completedPairIndices.length;

  @override
  SymmetrySessionSummary get symmetrySessionSummary {
    if (leftRepCount == 0 && rightRepCount == 0) {
      return SymmetrySessionSummary.empty;
    }

    final leftAverageRom = _leftAccumulator.averageRom;
    final rightAverageRom = _rightAccumulator.averageRom;
    final leftAverageTempo = _leftAccumulator.averageTempo;
    final rightAverageTempo = _rightAccumulator.averageTempo;
    final hasBothSides = leftRepCount > 0 && rightRepCount > 0;

    final repCountScore = _similarityScore(
      leftRepCount.toDouble(),
      rightRepCount.toDouble(),
    );
    final romScore = hasBothSides
        ? _similarityScore(leftAverageRom!, rightAverageRom!)
        : null;
    final tempoScore = hasBothSides
        ? _similarityScore(
            leftAverageTempo!.inMilliseconds.toDouble(),
            rightAverageTempo!.inMilliseconds.toDouble(),
          )
        : null;

    return SymmetrySessionSummary(
      leftRepCount: leftRepCount,
      rightRepCount: rightRepCount,
      pairedRepCount: pairedRepCount,
      repCountDifference: (leftRepCount - rightRepCount).abs(),
      repCountSymmetryScore: repCountScore,
      leftAverageRom: leftAverageRom,
      rightAverageRom: rightAverageRom,
      averageRomDifference: hasBothSides
          ? (leftAverageRom! - rightAverageRom!).abs()
          : null,
      romSymmetryScore: romScore,
      leftAverageTempo: leftAverageTempo,
      rightAverageTempo: rightAverageTempo,
      averageTempoDifference: hasBothSides
          ? Duration(
              milliseconds:
                  (leftAverageTempo!.inMilliseconds -
                          rightAverageTempo!.inMilliseconds)
                      .abs(),
            )
          : null,
      tempoSymmetryScore: tempoScore,
      overallSymmetryScore: hasBothSides
          ? (repCountScore + romScore! + tempoScore!) / 3
          : null,
    );
  }

  SymmetryRepResult? record({
    required SymmetrySide side,
    required int sideRepIndex,
    required double rom,
    required Duration tempo,
  }) {
    if (sideRepIndex <= 0) {
      throw ArgumentError.value(
        sideRepIndex,
        'sideRepIndex',
        'must be greater than zero',
      );
    }
    if (!rom.isFinite || rom < 0) {
      throw ArgumentError.value(rom, 'rom', 'must be finite and non-negative');
    }
    if (tempo.isNegative) {
      throw ArgumentError.value(tempo, 'tempo', 'must be non-negative');
    }

    final sample = _SymmetryRepSample(rom: rom, tempo: tempo);
    final ownSamples = _samplesFor(side);
    if (ownSamples.containsKey(sideRepIndex)) {
      throw StateError(
        'Symmetry sample already recorded for ${side.name} rep $sideRepIndex.',
      );
    }

    ownSamples[sideRepIndex] = sample;
    _accumulatorFor(side).record(rom: rom, tempo: tempo);

    final oppositeSample = _samplesFor(_opposite(side))[sideRepIndex];
    if (oppositeSample == null ||
        _completedPairIndices.contains(sideRepIndex)) {
      return null;
    }

    final left = _leftSamples[sideRepIndex]!;
    final right = _rightSamples[sideRepIndex]!;
    final romScore = _similarityScore(left.rom, right.rom);
    final tempoScore = _similarityScore(
      left.tempo.inMilliseconds.toDouble(),
      right.tempo.inMilliseconds.toDouble(),
    );
    final result = SymmetryRepResult(
      pairIndex: sideRepIndex,
      leftRom: left.rom,
      rightRom: right.rom,
      romDifference: (left.rom - right.rom).abs(),
      romSymmetryScore: romScore,
      leftTempo: left.tempo,
      rightTempo: right.tempo,
      tempoDifference: Duration(
        milliseconds: (left.tempo.inMilliseconds - right.tempo.inMilliseconds)
            .abs(),
      ),
      tempoSymmetryScore: tempoScore,
      overallSymmetryScore: (romScore + tempoScore) / 2,
    );
    _completedPairIndices.add(sideRepIndex);
    lastCompletedSymmetryPair = result;
    return result;
  }

  void reset() {
    _leftAccumulator.reset();
    _rightAccumulator.reset();
    _leftSamples.clear();
    _rightSamples.clear();
    _completedPairIndices.clear();
    lastCompletedSymmetryPair = null;
  }

  Map<int, _SymmetryRepSample> _samplesFor(SymmetrySide side) => switch (side) {
    SymmetrySide.left => _leftSamples,
    SymmetrySide.right => _rightSamples,
  };

  _SymmetrySideAccumulator _accumulatorFor(SymmetrySide side) => switch (side) {
    SymmetrySide.left => _leftAccumulator,
    SymmetrySide.right => _rightAccumulator,
  };

  SymmetrySide _opposite(SymmetrySide side) => switch (side) {
    SymmetrySide.left => SymmetrySide.right,
    SymmetrySide.right => SymmetrySide.left,
  };

  double _similarityScore(double left, double right) {
    final largestMagnitude = math.max(left.abs(), right.abs());
    if (largestMagnitude == 0) {
      return 100.0;
    }
    return (100 * (1 - (left - right).abs() / largestMagnitude))
        .clamp(0.0, 100.0)
        .toDouble();
  }
}

class _SymmetryRepSample {
  const _SymmetryRepSample({required this.rom, required this.tempo});

  final double rom;
  final Duration tempo;
}

class _SymmetrySideAccumulator {
  int repCount = 0;
  double _totalRom = 0.0;
  int _totalTempoMillis = 0;

  double? get averageRom => repCount == 0 ? null : _totalRom / repCount;
  Duration? get averageTempo => repCount == 0
      ? null
      : Duration(milliseconds: (_totalTempoMillis / repCount).round());

  void record({required double rom, required Duration tempo}) {
    repCount++;
    _totalRom += rom;
    _totalTempoMillis += tempo.inMilliseconds;
  }

  void reset() {
    repCount = 0;
    _totalRom = 0.0;
    _totalTempoMillis = 0;
  }
}
