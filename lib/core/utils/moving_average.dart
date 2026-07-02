import 'dart:collection';

/// Smooths noisy angle samples with a fixed-size moving average window.
class MovingAverageFilter {
  final int windowSize;
  final Queue<double> _values = Queue<double>();
  double _sum = 0.0;

  MovingAverageFilter({this.windowSize = 5});

  /// Adds a new sample and returns the current smoothed average.
  double process(double newValue) {
    _values.addLast(newValue);
    _sum += newValue;

    if (_values.length > windowSize) {
      double oldestValue = _values.removeFirst();
      _sum -= oldestValue;
    }

    return _sum / _values.length;
  }

  /// Clears previous samples before a fresh analysis session.
  void reset() {
    _values.clear();
    _sum = 0.0;
  }
}
