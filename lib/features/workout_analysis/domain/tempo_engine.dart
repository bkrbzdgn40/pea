import 'generic_rep_engine.dart';

/// Declares the muscle action performed while moving from neutral toward peak.
enum TempoTowardPeakAction { eccentric, concentric }

/// Canonical tempo facts for one completed repetition.
class TempoRepResult {
  const TempoRepResult({
    required this.repIndex,
    required this.eccentricDuration,
    required this.bottomPauseDuration,
    required this.concentricDuration,
    required this.topPauseDuration,
    required this.totalRepDuration,
    required this.towardPeakDuration,
    required this.returnDuration,
  });

  final int repIndex;
  final Duration eccentricDuration;
  final Duration bottomPauseDuration;
  final Duration concentricDuration;
  final Duration topPauseDuration;
  final Duration totalRepDuration;

  /// Topology-oriented duration from neutral toward the configured peak.
  final Duration towardPeakDuration;

  /// Topology-oriented duration from peak back toward neutral.
  final Duration returnDuration;
}

/// Aggregated session-level tempo metrics.
class TempoSessionSummary {
  const TempoSessionSummary({
    required this.repCount,
    required this.averageRepDuration,
    required this.fastestRepDuration,
    required this.slowestRepDuration,
    required this.consistencyScore,
    required this.averageEccentricDuration,
    required this.averageBottomPauseDuration,
    required this.averageConcentricDuration,
    required this.averageTopPauseDuration,
  });

  static const empty = TempoSessionSummary(
    repCount: 0,
    averageRepDuration: Duration.zero,
    fastestRepDuration: Duration.zero,
    slowestRepDuration: Duration.zero,
    consistencyScore: 0,
    averageEccentricDuration: Duration.zero,
    averageBottomPauseDuration: Duration.zero,
    averageConcentricDuration: Duration.zero,
    averageTopPauseDuration: Duration.zero,
  );

  final int repCount;
  final Duration averageRepDuration;
  final Duration fastestRepDuration;
  final Duration slowestRepDuration;

  /// 0-100 score derived from mean absolute deviation of rep durations.
  /// One completed rep is treated as perfectly consistent.
  final double consistencyScore;

  final Duration averageEccentricDuration;
  final Duration averageBottomPauseDuration;
  final Duration averageConcentricDuration;
  final Duration averageTopPauseDuration;
}

/// Reusable accumulator for session-level tempo facts.
class TempoSessionAccumulator {
  final List<int> _repDurationsMs = <int>[];
  int _totalRepDurationMs = 0;
  int _totalEccentricMs = 0;
  int _totalBottomPauseMs = 0;
  int _totalConcentricMs = 0;
  int _totalTopPauseMs = 0;
  int? _fastestRepMs;
  int? _slowestRepMs;

  int get repCount => _repDurationsMs.length;

  TempoSessionSummary get summary {
    final count = repCount;
    if (count == 0) {
      return TempoSessionSummary.empty;
    }

    final averageRepMs = _totalRepDurationMs / count;
    final meanAbsoluteDeviationMs =
        _repDurationsMs
            .map((durationMs) => (durationMs - averageRepMs).abs())
            .fold<double>(0.0, (sum, deviation) => sum + deviation) /
        count;
    final consistencyScore = averageRepMs <= 0
        ? 100.0
        : (100 * (1 - meanAbsoluteDeviationMs / averageRepMs))
              .clamp(0.0, 100.0)
              .toDouble();

    return TempoSessionSummary(
      repCount: count,
      averageRepDuration: Duration(
        milliseconds: (_totalRepDurationMs / count).round(),
      ),
      fastestRepDuration: Duration(milliseconds: _fastestRepMs ?? 0),
      slowestRepDuration: Duration(milliseconds: _slowestRepMs ?? 0),
      consistencyScore: consistencyScore,
      averageEccentricDuration: Duration(
        milliseconds: (_totalEccentricMs / count).round(),
      ),
      averageBottomPauseDuration: Duration(
        milliseconds: (_totalBottomPauseMs / count).round(),
      ),
      averageConcentricDuration: Duration(
        milliseconds: (_totalConcentricMs / count).round(),
      ),
      averageTopPauseDuration: Duration(
        milliseconds: (_totalTopPauseMs / count).round(),
      ),
    );
  }

  void record(TempoRepResult rep) {
    final repDurationMs = rep.totalRepDuration.inMilliseconds;
    _repDurationsMs.add(repDurationMs);
    _totalRepDurationMs += repDurationMs;
    _totalEccentricMs += rep.eccentricDuration.inMilliseconds;
    _totalBottomPauseMs += rep.bottomPauseDuration.inMilliseconds;
    _totalConcentricMs += rep.concentricDuration.inMilliseconds;
    _totalTopPauseMs += rep.topPauseDuration.inMilliseconds;
    _fastestRepMs = _fastestRepMs == null || repDurationMs < _fastestRepMs!
        ? repDurationMs
        : _fastestRepMs;
    _slowestRepMs = _slowestRepMs == null || repDurationMs > _slowestRepMs!
        ? repDurationMs
        : _slowestRepMs;
  }

  void reset() {
    _repDurationsMs.clear();
    _totalRepDurationMs = 0;
    _totalEccentricMs = 0;
    _totalBottomPauseMs = 0;
    _totalConcentricMs = 0;
    _totalTopPauseMs = 0;
    _fastestRepMs = null;
    _slowestRepMs = null;
  }
}

/// Read-only tempo capability exposed by rep engines that aggregate tempo.
abstract interface class TempoMetricsSource {
  TempoRepResult? get lastCompletedTempo;

  TempoSessionSummary get tempoSessionSummary;
}

/// Central tempo engine driven by confirmed [GenericRepEngine] transitions.
///
/// It owns phase timing and session aggregation, but deliberately knows nothing
/// about pose landmarks, scoring, feedback, persistence, or exercise-specific
/// thresholds.
class TempoEngine {
  TempoEngine({this.towardPeakAction = TempoTowardPeakAction.eccentric});

  final TempoTowardPeakAction towardPeakAction;
  final TempoSessionAccumulator _sessionAccumulator = TempoSessionAccumulator();

  DateTime? _neutralStartedAt;
  DateTime? _repStartedAt;
  DateTime? _peakStartedAt;
  DateTime? _returnStartedAt;
  Duration _topPauseDuration = Duration.zero;
  Duration _towardPeakDuration = Duration.zero;
  Duration _bottomPauseDuration = Duration.zero;

  TempoRepResult? lastCompletedRep;

  TempoSessionSummary get sessionSummary => _sessionAccumulator.summary;

  TempoRepResult? process(GenericRepEngineFrameResult frameResult) {
    final transition = frameResult.confirmedTransition;
    if (transition == null) {
      return null;
    }

    final effectiveAt = transition.effectiveAt;
    switch (transition.type) {
      case GenericRepTransitionType.acquireNeutral:
        _neutralStartedAt = effectiveAt;
        return null;

      case GenericRepTransitionType.startTowardPeak:
        _topPauseDuration = _safeDifference(effectiveAt, _neutralStartedAt);
        _repStartedAt = effectiveAt;
        _peakStartedAt = null;
        _returnStartedAt = null;
        _towardPeakDuration = Duration.zero;
        _bottomPauseDuration = Duration.zero;
        return null;

      case GenericRepTransitionType.reachPeak:
        _towardPeakDuration = _safeDifference(effectiveAt, _repStartedAt);
        _peakStartedAt = effectiveAt;
        return null;

      case GenericRepTransitionType.startReturning:
        _bottomPauseDuration = _safeDifference(effectiveAt, _peakStartedAt);
        _returnStartedAt = effectiveAt;
        return null;

      case GenericRepTransitionType.abortToNeutral:
        interrupt(neutralAt: effectiveAt);
        return null;

      case GenericRepTransitionType.completeRep:
        final completedRep = frameResult.completedRep;
        if (completedRep == null) {
          interrupt(neutralAt: effectiveAt);
          return null;
        }

        final returnDuration = _safeDifference(effectiveAt, _returnStartedAt);
        final totalRepDuration = _safeDifference(effectiveAt, _repStartedAt);
        final eccentricDuration = switch (towardPeakAction) {
          TempoTowardPeakAction.eccentric => _towardPeakDuration,
          TempoTowardPeakAction.concentric => returnDuration,
        };
        final concentricDuration = switch (towardPeakAction) {
          TempoTowardPeakAction.eccentric => returnDuration,
          TempoTowardPeakAction.concentric => _towardPeakDuration,
        };

        final result = TempoRepResult(
          repIndex: completedRep.repIndex,
          eccentricDuration: eccentricDuration,
          bottomPauseDuration: _bottomPauseDuration,
          concentricDuration: concentricDuration,
          topPauseDuration: _topPauseDuration,
          totalRepDuration: totalRepDuration,
          towardPeakDuration: _towardPeakDuration,
          returnDuration: returnDuration,
        );
        lastCompletedRep = result;
        _sessionAccumulator.record(result);
        _clearActiveRep();
        _neutralStartedAt = effectiveAt;
        return result;
    }
  }

  /// Excludes a known camera/visibility gap from the active rep durations.
  void shiftActiveTiming(Duration delta) {
    if (delta <= Duration.zero) {
      return;
    }
    if (_repStartedAt != null) {
      _repStartedAt = _repStartedAt!.add(delta);
    }
    if (_peakStartedAt != null) {
      _peakStartedAt = _peakStartedAt!.add(delta);
    }
    if (_returnStartedAt != null) {
      _returnStartedAt = _returnStartedAt!.add(delta);
    }
  }

  /// Clears an in-progress repetition while preserving completed session stats.
  void interrupt({DateTime? neutralAt}) {
    _clearActiveRep();
    _neutralStartedAt = neutralAt;
  }

  void reset() {
    _sessionAccumulator.reset();
    lastCompletedRep = null;
    _neutralStartedAt = null;
    _clearActiveRep();
  }

  void _clearActiveRep() {
    _repStartedAt = null;
    _peakStartedAt = null;
    _returnStartedAt = null;
    _topPauseDuration = Duration.zero;
    _towardPeakDuration = Duration.zero;
    _bottomPauseDuration = Duration.zero;
  }

  Duration _safeDifference(DateTime end, DateTime? start) {
    if (start == null) {
      return Duration.zero;
    }
    final duration = end.difference(start);
    return duration.isNegative ? Duration.zero : duration;
  }
}
