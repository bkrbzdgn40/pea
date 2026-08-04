import 'package:flutter/foundation.dart';

import 'market_product.dart';
import 'money.dart';

@immutable
class MarketCartLine {
  const MarketCartLine({required this.product, required this.quantity})
    : assert(quantity > 0);

  final MarketProduct product;
  final int quantity;

  Money get lineTotal => Money(
    minorUnits: product.price.minorUnits * quantity,
    currencyCode: product.price.currencyCode,
  );

  MarketCartLine copyWith({int? quantity}) {
    return MarketCartLine(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }
}
