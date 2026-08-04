import 'package:flutter/foundation.dart';

import 'market_category.dart';
import 'money.dart';

@immutable
class MarketProduct {
  const MarketProduct({
    required this.id,
    required this.category,
    required this.price,
    this.imageAssetPath,
    this.isFeatured = false,
  });

  final String id;
  final MarketCategory category;
  final Money price;
  final String? imageAssetPath;
  final bool isFeatured;
}
