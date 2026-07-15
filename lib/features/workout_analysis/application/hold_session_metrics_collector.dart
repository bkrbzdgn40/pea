import 'workout_state.dart';

/// Collects persisted hold-session totals from production workout state updates.
class HoldSessionMetricsCollector {
  double _lastObservedHoldSeconds = 0.0;
  double _totalHoldSeconds = 0.0;
  double _bestHoldSeconds = 0.0;
  int _formBreakCount = 0;
  bool _previousHoldFormBreak = false;

  double get totalHoldSeconds => _totalHoldSeconds;
  double get bestHoldSeconds => _bestHoldSeconds;
  int get formBreakCount => _formBreakCount;

  void reset() {
    _lastObservedHoldSeconds = 0.0;
    _totalHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _formBreakCount = 0;
    _previousHoldFormBreak = false;
  }

  void collect(WorkoutState next) {
    final holdAnalysis = next.holdAnalysis;
    if (holdAnalysis == null) {
      _lastObservedHoldSeconds = 0.0;
      _previousHoldFormBreak = false;
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

    if (!_previousHoldFormBreak && holdAnalysis.hadHoldFormBreak) {
      _formBreakCount += 1;
    }

    _lastObservedHoldSeconds =
        holdAnalysis.isHolding || holdAnalysis.isHoldVisibilitySuspended
        ? holdAnalysis.currentHoldSeconds
        : 0.0;
    _previousHoldFormBreak = holdAnalysis.hadHoldFormBreak;
  }
}
