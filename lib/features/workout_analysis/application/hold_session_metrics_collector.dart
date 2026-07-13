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
    if (next.isHolding) {
      final holdDelta = next.currentHoldSeconds - _lastObservedHoldSeconds;
      if (holdDelta > 0) {
        _totalHoldSeconds += holdDelta;
      }
    }

    if (next.bestHoldSeconds > _bestHoldSeconds) {
      _bestHoldSeconds = next.bestHoldSeconds;
    }

    if (!_previousHoldFormBreak && next.hadHoldFormBreak) {
      _formBreakCount += 1;
    }

    _lastObservedHoldSeconds = next.isHolding || next.isHoldVisibilitySuspended
        ? next.currentHoldSeconds
        : 0.0;
    _previousHoldFormBreak = next.hadHoldFormBreak;
  }
}
