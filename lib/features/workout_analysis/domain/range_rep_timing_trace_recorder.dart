import 'generic_rep_engine.dart';
import 'range_rep_timing_trace.dart';

/// Mutable owner for the timing observations of one active range repetition.
///
/// The engine reports lifecycle facts to this recorder, while the recorder owns
/// trace mutation, finalization, and the most recently ended immutable snapshot.
class RangeRepTimingTraceRecorder {
  static const double _directionEpsilon = 0.5;

  bool _isActive = false;
  int _sampleCount = 0;
  int _towardPeakSampleCount = 0;
  int _peakSampleCount = 0;
  int _returnSampleCount = 0;
  int _directionChangeCount = 0;
  int _nonMonotonicObservationCount = 0;
  int _invalidProcessingLagCount = 0;
  int _intervalSampleCount = 0;
  int _totalObservationIntervalUs = 0;
  int? _maxObservationIntervalMs;
  int? _lastProcessingLagMs;
  int? _maxProcessingLagMs;
  DateTime? _firstObservedAt;
  DateTime? _lastObservedAt;
  double? _firstPrimaryMetric;
  double? _lastPrimaryMetric;
  double? _minPrimaryMetric;
  double? _maxPrimaryMetric;
  int _lastDirection = 0;
  bool _hadVisibilityGap = false;
  bool _usedSparseCycleRecovery = false;
  final List<RangeRepTimingTransitionTrace> _transitions =
      <RangeRepTimingTransitionTrace>[];
  RangeRepTimingTraceSnapshot? _lastEndedSnapshot;

  bool get isActive => _isActive;

  RangeRepTimingTraceSnapshot? get activeSnapshot =>
      _isActive ? _snapshot(outcome: RangeRepTimingTraceOutcome.active) : null;

  RangeRepTimingTraceSnapshot? get lastEndedSnapshot => _lastEndedSnapshot;

  void start() {
    _resetActive();
    _isActive = true;
  }

  void record({
    required GenericRepPhase phase,
    required double primaryMetric,
    required DateTime observedAt,
    required DateTime processedAt,
  }) {
    if (!_isActive) {
      return;
    }

    final previousObservedAt = _lastObservedAt;
    if (previousObservedAt != null) {
      final interval = observedAt.difference(previousObservedAt);
      if (interval.isNegative) {
        _nonMonotonicObservationCount++;
        return;
      }
      _intervalSampleCount++;
      _totalObservationIntervalUs += interval.inMicroseconds;
      final intervalMs = interval.inMilliseconds;
      _maxObservationIntervalMs =
          _maxObservationIntervalMs == null ||
              intervalMs > _maxObservationIntervalMs!
          ? intervalMs
          : _maxObservationIntervalMs;
    }

    final processingLag = processedAt.difference(observedAt);
    if (processingLag.isNegative) {
      _invalidProcessingLagCount++;
    } else {
      final processingLagMs = processingLag.inMilliseconds;
      _lastProcessingLagMs = processingLagMs;
      _maxProcessingLagMs =
          _maxProcessingLagMs == null || processingLagMs > _maxProcessingLagMs!
          ? processingLagMs
          : _maxProcessingLagMs;
    }

    _firstObservedAt ??= observedAt;
    _lastObservedAt = observedAt;
    _firstPrimaryMetric ??= primaryMetric;
    final previousMetric = _lastPrimaryMetric;
    if (previousMetric != null) {
      final delta = primaryMetric - previousMetric;
      final direction = delta > _directionEpsilon
          ? 1
          : delta < -_directionEpsilon
          ? -1
          : 0;
      if (direction != 0) {
        if (_lastDirection != 0 && direction != _lastDirection) {
          _directionChangeCount++;
        }
        _lastDirection = direction;
      }
    }
    _lastPrimaryMetric = primaryMetric;
    _minPrimaryMetric =
        _minPrimaryMetric == null || primaryMetric < _minPrimaryMetric!
        ? primaryMetric
        : _minPrimaryMetric;
    _maxPrimaryMetric =
        _maxPrimaryMetric == null || primaryMetric > _maxPrimaryMetric!
        ? primaryMetric
        : _maxPrimaryMetric;

    _sampleCount++;
    switch (phase) {
      case GenericRepPhase.neutral:
        break;
      case GenericRepPhase.towardPeak:
        _towardPeakSampleCount++;
        break;
      case GenericRepPhase.peak:
        _peakSampleCount++;
        break;
      case GenericRepPhase.returning:
        _returnSampleCount++;
        break;
    }
  }

  void recordRejectedObservation() {
    if (_isActive) {
      _nonMonotonicObservationCount++;
    }
  }

  void addTransitions(Iterable<GenericRepConfirmedTransition> transitions) {
    if (!_isActive) {
      return;
    }
    for (final transition in transitions) {
      _transitions.add(
        RangeRepTimingTransitionTrace(
          type: transition.type.name,
          effectiveAt: transition.effectiveAt,
          confirmedAt: transition.confirmedAt,
        ),
      );
    }
  }

  void markVisibilityGap() {
    if (_isActive) {
      _hadVisibilityGap = true;
    }
  }

  void markSparseCycleRecovery() {
    if (_isActive) {
      _usedSparseCycleRecovery = true;
    }
  }

  RangeRepTimingTraceSnapshot? finish(RangeRepTimingTraceOutcome outcome) {
    if (!_isActive) {
      return null;
    }
    final snapshot = _snapshot(outcome: outcome);
    _lastEndedSnapshot = snapshot;
    _resetActive();
    return snapshot;
  }

  void reset() {
    _resetActive();
    _lastEndedSnapshot = null;
  }

  RangeRepTimingTraceSnapshot _snapshot({
    required RangeRepTimingTraceOutcome outcome,
  }) {
    final averageObservationIntervalMs = _intervalSampleCount == 0
        ? null
        : (_totalObservationIntervalUs / _intervalSampleCount) / 1000.0;
    return RangeRepTimingTraceSnapshot(
      outcome: outcome,
      sampleCount: _sampleCount,
      towardPeakSampleCount: _towardPeakSampleCount,
      peakSampleCount: _peakSampleCount,
      returnSampleCount: _returnSampleCount,
      directionChangeCount: _directionChangeCount,
      nonMonotonicObservationCount: _nonMonotonicObservationCount,
      invalidProcessingLagCount: _invalidProcessingLagCount,
      intervalSampleCount: _intervalSampleCount,
      averageObservationIntervalMs: averageObservationIntervalMs,
      maxObservationIntervalMs: _maxObservationIntervalMs,
      lastProcessingLagMs: _lastProcessingLagMs,
      maxProcessingLagMs: _maxProcessingLagMs,
      firstObservedAt: _firstObservedAt,
      lastObservedAt: _lastObservedAt,
      firstPrimaryMetric: _firstPrimaryMetric,
      lastPrimaryMetric: _lastPrimaryMetric,
      minPrimaryMetric: _minPrimaryMetric,
      maxPrimaryMetric: _maxPrimaryMetric,
      hadVisibilityGap: _hadVisibilityGap,
      usedSparseCycleRecovery: _usedSparseCycleRecovery,
      transitions: List<RangeRepTimingTransitionTrace>.unmodifiable(
        _transitions,
      ),
    );
  }

  void _resetActive() {
    _isActive = false;
    _sampleCount = 0;
    _towardPeakSampleCount = 0;
    _peakSampleCount = 0;
    _returnSampleCount = 0;
    _directionChangeCount = 0;
    _nonMonotonicObservationCount = 0;
    _invalidProcessingLagCount = 0;
    _intervalSampleCount = 0;
    _totalObservationIntervalUs = 0;
    _maxObservationIntervalMs = null;
    _lastProcessingLagMs = null;
    _maxProcessingLagMs = null;
    _firstObservedAt = null;
    _lastObservedAt = null;
    _firstPrimaryMetric = null;
    _lastPrimaryMetric = null;
    _minPrimaryMetric = null;
    _maxPrimaryMetric = null;
    _lastDirection = 0;
    _hadVisibilityGap = false;
    _usedSparseCycleRecovery = false;
    _transitions.clear();
  }
}
