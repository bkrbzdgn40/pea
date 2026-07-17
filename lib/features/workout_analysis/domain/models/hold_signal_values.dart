import 'hold_contract.dart';

class HoldSignalValues {
  const HoldSignalValues.empty() : _values = const <HoldSignal, double>{};

  factory HoldSignalValues({
    Map<HoldSignal, double> values = const <HoldSignal, double>{},
  }) {
    return HoldSignalValues._(Map<HoldSignal, double>.unmodifiable(values));
  }

  factory HoldSignalValues.legacy({
    double? alignment,
    double? support,
    double? extension,
  }) {
    final values = <HoldSignal, double>{};
    if (alignment != null) {
      values[HoldSignal.alignment] = alignment;
    }
    if (support != null) {
      values[HoldSignal.support] = support;
    }
    if (extension != null) {
      values[HoldSignal.extension] = extension;
    }

    return HoldSignalValues(values: values);
  }

  const HoldSignalValues._(this._values);

  final Map<HoldSignal, double> _values;

  double? valueFor(HoldSignal signal) => _values[signal];

  bool hasValue(HoldSignal signal) => _values.containsKey(signal);

  Iterable<HoldSignal> get signals => _values.keys;

  Map<HoldSignal, double> asMap() {
    return Map<HoldSignal, double>.unmodifiable(_values);
  }
}
