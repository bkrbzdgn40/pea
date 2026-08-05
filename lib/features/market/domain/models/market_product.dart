import 'package:flutter/foundation.dart';

import 'market_category.dart';
import 'money.dart';

@immutable
class MarketProduct {
  const MarketProduct({
    required this.id,
    required this.category,
    required this.price,
    String? imageAssetPath,
    this.imageAssetPaths = const <String>[],
    this.isFeatured = false,
  }) : _legacyImageAssetPath = imageAssetPath;

  final String id;
  final MarketCategory category;
  final Money price;

  /// Kept for source compatibility with existing callers while catalog entries
  /// migrate to [imageAssetPaths].
  final String? _legacyImageAssetPath;

  /// Ordered product gallery assets. The first image is used as the catalog
  /// thumbnail.
  final List<String> imageAssetPaths;

  final bool isFeatured;

  String? get imageAssetPath => imageAssetPaths.isNotEmpty
      ? imageAssetPaths.first
      : _legacyImageAssetPath;

  List<String> get galleryImageAssetPaths {
    if (imageAssetPaths.isNotEmpty) {
      return imageAssetPaths;
    }

    final legacyImageAssetPath = _legacyImageAssetPath;
    return legacyImageAssetPath == null
        ? const <String>[]
        : <String>[legacyImageAssetPath];
  }
}
