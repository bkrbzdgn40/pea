import 'workout_state.dart';

/// Collects persisted hold-session totals from production workout state updates.
class HoldSessionMetricsCollector {
  double _lastObservedHoldSeconds = 0.0;
  double _totalHoldSeconds = 0.0;
  double _bestHoldSeconds = 0.0;
  int _formBreakCount = 0;
  bool _previousHoldFormBreak = false;
  double _measurementConfidenceSum = 0.0;
  int _measurementSampleCount = 0;
  int _observedHoldFrameCount = 0;
  int _visibilityInterruptedFrameCount = 0;
  _HoldEvidenceSnapshot? _lastEvidenceSnapshot;

  double get totalHoldSeconds => _totalHoldSeconds;
  double get bestHoldSeconds => _bestHoldSeconds;
  int get formBreakCount => _formBreakCount;
  int get measurementSampleCount => _measurementSampleCount;
  int get observedHoldFrameCount => _observedHoldFrameCount;
  int get visibilityInterruptedFrameCount => _visibilityInterruptedFrameCount;
  double? get averageMeasurementConfidence => _measurementSampleCount == 0
      ? null
      : _measurementConfidenceSum / _measurementSampleCount;

  void reset() {
    _lastObservedHoldSeconds = 0.0;
    _totalHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _formBreakCount = 0;
    _previousHoldFormBreak = false;
    _measurementConfidenceSum = 0.0;
    _measurementSampleCount = 0;
    _observedHoldFrameCount = 0;
    _visibilityInterruptedFrameCount = 0;
    _lastEvidenceSnapshot = null;
  }

  void collect(WorkoutState next) {
    _collect(next, countEvidenceFrame: true);
  }

  /// Collects the final UI snapshot without counting an evidence frame twice.
  ///
  /// The live state listener normally forwards every frame through [collect].
  /// Finishing then receives the latest state once more so persistence can catch
  /// any final rep/hold delta. For hold sessions that latest state is frequently
  /// the same evidence frame, so counting it again would bias sample counts and
  /// visibility ratios. A genuinely newer final snapshot is still counted.
  void collectFinalSnapshot(WorkoutState next) {
    final snapshot = _HoldEvidenceSnapshot.tryFromState(next);
    final isDuplicateEvidenceFrame =
        snapshot != null && snapshot == _lastEvidenceSnapshot;
    _collect(next, countEvidenceFrame: !isDuplicateEvidenceFrame);
  }

  void _collect(WorkoutState next, {required bool countEvidenceFrame}) {
    final holdAnalysis = next.holdAnalysis;
    if (holdAnalysis == null) {
      _lastObservedHoldSeconds = 0.0;
      _previousHoldFormBreak = false;
      _lastEvidenceSnapshot = null;
      return;
    }

    if (holdAnalysis.isHolding) {
      final holdDelta =
          holdAnalysis.currentHoldSeconds - _lastObservedHoldSeconds;
      if (holdDelta > 0) {
        _totalHoldSeconds += holdDelta;
      }
    }

    if (holdAnalysis.bestHoldSeconds > _bestHoldSeconds) {
      _bestHoldSeconds = holdAnalysis.bestHoldSeconds;
    }

    final isEvidenceWindow =
        holdAnalysis.isHolding || holdAnalysis.isHoldVisibilitySuspended;
    if (isEvidenceWindow && countEvidenceFrame) {
      _observedHoldFrameCount += 1;
      if (holdAnalysis.isHoldVisibilitySuspended) {
        _visibilityInterruptedFrameCount += 1;
      }

      final confidence = holdAnalysis.holdMeasurementConfidence?.combined;
      if (holdAnalysis.isHoldMeasurementFrameAccepted &&
          confidence != null &&
          confidence.isFinite) {
        _measurementConfidenceSum += confidence;
        _measurementSampleCount += 1;
      }
    }

    if (!_previousHoldFormBreak && holdAnalysis.hadHoldFormBreak) {
      _formBreakCount += 1;
    }

    _lastObservedHoldSeconds =
        holdAnalysis.isHolding || holdAnalysis.isHoldVisibilitySuspended
        ? holdAnalysis.currentHoldSeconds
        : 0.0;
    _previousHoldFormBreak = holdAnalysis.hadHoldFormBreak;
    _lastEvidenceSnapshot = _HoldEvidenceSnapshot.tryFromState(next);
  }
}

class _HoldEvidenceSnapshot {
  const _HoldEvidenceSnapshot({
    required this.currentHoldSeconds,
    required this.isHolding,
    required this.isVisibilitySuspended,
    required this.isMeasurementFrameAccepted,
    required this.measurementConfidence,
  });

  static _HoldEvidenceSnapshot? tryFromState(WorkoutState state) {
    final analysis = state.holdAnalysis;
    if (analysis == null) {
      return null;
    }
    return _HoldEvidenceSnapshot(
      currentHoldSeconds: analysis.currentHoldSeconds,
      isHolding: analysis.isHolding,
      isVisibilitySuspended: analysis.isHoldVisibilitySuspended,
      isMeasurementFrameAccepted: analysis.isHoldMeasurementFrameAccepted,
      measurementConfidence: analysis.holdMeasurementConfidence?.combined,
    );
  }

  final double currentHoldSeconds;
  final bool isHolding;
  final bool isVisibilitySuspended;
  final bool isMeasurementFrameAccepted;
  final double? measurementConfidence;

  @override
  bool operator ==(Object other) {
    return other is _HoldEvidenceSnapshot &&
        other.currentHoldSeconds == currentHoldSeconds &&
        other.isHolding == isHolding &&
        other.isVisibilitySuspended == isVisibilitySuspended &&
        other.isMeasurementFrameAccepted == isMeasurementFrameAccepted &&
        other.measurementConfidence == measurementConfidence;
  }

  @override
  int get hashCode => Object.hash(
    currentHoldSeconds,
    isHolding,
    isVisibilitySuspended,
    isMeasurementFrameAccepted,
    measurementConfidence,
  );
}
