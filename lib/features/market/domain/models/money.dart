import 'package:flutter/foundation.dart';

@immutable
class Money {
  const Money({required this.minorUnits, required this.currencyCode})
    : assert(minorUnits >= 0),
      assert(currencyCode.length == 3);

  final int minorUnits;
  final String currencyCode;

  double get majorUnits => minorUnits / 100;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Money &&
            other.minorUnits == minorUnits &&
            other.currencyCode == currencyCode;
  }

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);
}
