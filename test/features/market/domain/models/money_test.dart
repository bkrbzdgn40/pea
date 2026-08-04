import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/money.dart';

void main() {
  test('exposes major units without storing price as a double', () {
    const money = Money(minorUnits: 129990, currencyCode: 'TRY');

    expect(money.minorUnits, 129990);
    expect(money.majorUnits, 1299.9);
    expect(money.currencyCode, 'TRY');
  });

  test('compares equal monetary values by amount and currency', () {
    expect(
      const Money(minorUnits: 49900, currencyCode: 'TRY'),
      const Money(minorUnits: 49900, currencyCode: 'TRY'),
    );
  });
}
