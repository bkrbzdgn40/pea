import 'dart:math' as math;

import '../domain/models/validated_rep_event.dart';
import '../domain/symmetry_engine.dart';

/// Consumes validated rep events for alternating movements.
///
/// Main rep counting remains owned by range-rep validation. This tracker only
/// projects that same event stream into side counts and symmetry metrics.
class ValidatedRepEventTracker {
  final Set<int> _recordedAttemptIndices = <int>{};
  final _ValidatedSideAccumulator _left = _ValidatedSideAccumulator();
  final _ValidatedSideAccumulator _right = _ValidatedSideAccumulator();

  int get totalRepCount => _left.repCount + _right.repCount;
  int get leftRepCount => _left.repCount;
  int get rightRepCount => _right.repCount;
  int get leftRomSampleCount => _left.romSampleCount;
  int get rightRomSampleCount => _right.romSampleCount;

  SymmetrySessionSummary get symmetrySessionSummary {
    if (totalRepCount == 0) {
      return SymmetrySessionSummary.empty;
    }

    final hasBothRomSides =
        _left.romSampleCount > 0 && _right.romSampleCount > 0;
    final hasBothTempoSides =
        _left.tempoSampleCount > 0 && _right.tempoSampleCount > 0;
    final repCountSymmetryScore = _similarityScore(
      leftRepCount.toDouble(),
      rightRepCount.toDouble(),
    );
    final romSymmetryScore = hasBothRomSides
        ? _similarityScore(_left.averageRom!, _right.averageRom!)
        : null;
    final tempoSymmetryScore = hasBothTempoSides
        ? _similarityScore(
            _left.averageTempo!.inMilliseconds.toDouble(),
            _right.averageTempo!.inMilliseconds.toDouble(),
          )
        : null;

    return SymmetrySessionSummary(
      leftRepCount: leftRepCount,
      rightRepCount: rightRepCount,
      pairedRepCount: math.min(_left.romSampleCount, _right.romSampleCount),
      repCountDifference: (leftRepCount - rightRepCount).abs(),
      repCountSymmetryScore: repCountSymmetryScore,
      leftAverageRom: _left.averageRom,
      rightAverageRom: _right.averageRom,
      averageRomDifference: hasBothRomSides
          ? (_left.averageRom! - _right.averageRom!).abs()
          : null,
      romSymmetryScore: romSymmetryScore,
      leftAverageTempo: _left.averageTempo,
      rightAverageTempo: _right.averageTempo,
      averageTempoDifference: hasBothTempoSides
          ? Duration(
              milliseconds:
                  (_left.averageTempo!.inMilliseconds -
                          _right.averageTempo!.inMilliseconds)
                      .abs(),
            )
          : null,
      tempoSymmetryScore: tempoSymmetryScore,
      overallSymmetryScore: romSymmetryScore == null
          ? null
          : (repCountSymmetryScore + romSymmetryScore) / 2,
    );
  }

  /// Returns false when the same validated attempt has already been consumed.
  bool record(ValidatedRepEvent event) {
    if (_recordedAttemptIndices.contains(event.attemptIndex)) {
      return false;
    }
    if (!event.countsTowardReps) {
      _recordedAttemptIndices.add(event.attemptIndex);
      return true;
    }

    final acceptedRepIndex = event.acceptedRepIndex;
    final expectedAcceptedRepIndex = totalRepCount + 1;
    if (acceptedRepIndex != expectedAcceptedRepIndex) {
      throw StateError(
        'Accepted alternating rep ${event.attemptIndex} has accepted index '
        '$acceptedRepIndex; expected $expectedAcceptedRepIndex.',
      );
    }

    final side = event.side;
    if (side == null) {
      throw StateError(
        'Accepted alternating rep ${event.attemptIndex} has no validated side.',
      );
    }

    _recordedAttemptIndices.add(event.attemptIndex);
    final accumulator = switch (side) {
      ValidatedRepSide.left => _left,
      ValidatedRepSide.right => _right,
    };
    accumulator.recordAcceptedRep();

    if (event.isRomSymmetryEligible) {
      accumulator.recordRom(event.primaryRom!);
    }
    if (event.isTempoSymmetryEligible) {
      final measuredTempo = event.tempoAssessment!.measurement.measuredTempo;
      if (measuredTempo != null) {
        accumulator.recordTempo(measuredTempo.totalRepDuration);
      }
    }
    return true;
  }

  void reset() {
    _recordedAttemptIndices.clear();
    _left.reset();
    _right.reset();
  }

  double _similarityScore(double left, double right) {
    final largestMagnitude = math.max(left.abs(), right.abs());
    if (largestMagnitude == 0) {
      return 100;
    }
    return (100 * (1 - (left - right).abs() / largestMagnitude))
        .clamp(0.0, 100.0)
        .toDouble();
  }
}

class _ValidatedSideAccumulator {
  int repCount = 0;
  int romSampleCount = 0;
  int tempoSampleCount = 0;
  double _totalRom = 0;
  int _totalTempoMillis = 0;

  double? get averageRom =>
      romSampleCount == 0 ? null : _totalRom / romSampleCount;

  Duration? get averageTempo => tempoSampleCount == 0
      ? null
      : Duration(milliseconds: (_totalTempoMillis / tempoSampleCount).round());

  void recordAcceptedRep() {
    repCount += 1;
  }

  void recordRom(double rom) {
    romSampleCount += 1;
    _totalRom += rom;
  }

  void recordTempo(Duration tempo) {
    tempoSampleCount += 1;
    _totalTempoMillis += tempo.inMilliseconds;
  }

  void reset() {
    repCount = 0;
    romSampleCount = 0;
    tempoSampleCount = 0;
    _totalRom = 0;
    _totalTempoMillis = 0;
  }
}
