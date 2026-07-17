import 'hold_contract.dart';

class HoldSignalValidity {
  const HoldSignalValidity.empty() : _values = const <HoldSignal, bool>{};

  factory HoldSignalValidity({
    Map<HoldSignal, bool> values = const <HoldSignal, bool>{},
  }) {
    return HoldSignalValidity._(Map<HoldSignal, bool>.unmodifiable(values));
  }

  const HoldSignalValidity._(this._values);

  final Map<HoldSignal, bool> _values;

  bool? validityFor(HoldSignal signal) => _values[signal];

  Iterable<HoldSignal> get signals => _values.keys;

  Map<HoldSignal, bool> asMap() {
    return Map<HoldSignal, bool>.unmodifiable(_values);
  }
}
