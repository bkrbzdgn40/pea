import 'package:flutter/foundation.dart';

import 'market_cart_line.dart';
import 'money.dart';

@immutable
class MarketCart {
  const MarketCart({
    this.lines = const <MarketCartLine>[],
    this.currencyCode = 'TRY',
  });

  final List<MarketCartLine> lines;
  final String currencyCode;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get itemCount =>
      lines.fold<int>(0, (total, line) => total + line.quantity);

  Money get subtotal => Money(
    minorUnits: lines.fold<int>(
      0,
      (total, line) => total + line.lineTotal.minorUnits,
    ),
    currencyCode: currencyCode,
  );

  int quantityFor(String productId) {
    for (final line in lines) {
      if (line.product.id == productId) {
        return line.quantity;
      }
    }
    return 0;
  }

  MarketCart copyWith({List<MarketCartLine>? lines, String? currencyCode}) {
    return MarketCart(
      lines: List<MarketCartLine>.unmodifiable(lines ?? this.lines),
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
