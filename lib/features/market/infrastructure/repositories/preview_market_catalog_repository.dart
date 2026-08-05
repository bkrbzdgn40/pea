import 'dart:convert';

import 'package:flutter/services.dart';

import '../../application/repositories/market_catalog_repository.dart';
import '../../domain/models/market_category.dart';
import '../../domain/models/market_product.dart';
import '../../domain/models/money.dart';

class PreviewMarketCatalogRepository implements MarketCatalogRepository {
  PreviewMarketCatalogRepository({
    AssetBundle? bundle,
    this.assetPath = defaultAssetPath,
  }) : _bundle = bundle ?? rootBundle;

  static const String defaultAssetPath = 'assets/market/preview_catalog.json';
  static const int supportedSchemaVersion = 1;

  final AssetBundle _bundle;
  final String assetPath;

  @override
  Future<List<MarketProduct>> loadProducts() async {
    final rawCatalog = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(rawCatalog);

    if (decoded is! Map) {
      throw const FormatException(
        'Market catalog asset must decode to a JSON object.',
      );
    }

    final catalog = Map<String, dynamic>.from(decoded);
    final schemaVersion = catalog['schemaVersion'];
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException(
        'Unsupported market catalog schema version: $schemaVersion.',
      );
    }

    final rawProducts = catalog['products'];
    if (rawProducts is! List || rawProducts.isEmpty) {
      throw const FormatException(
        'Market catalog must contain at least one product.',
      );
    }

    final products = <MarketProduct>[];
    final productIds = <String>{};

    for (var index = 0; index < rawProducts.length; index++) {
      final product = _parseProduct(rawProducts[index], index);
      if (!productIds.add(product.id)) {
        throw FormatException(
          'Market catalog contains duplicate product id: ${product.id}.',
        );
      }
      products.add(product);
    }

    return List<MarketProduct>.unmodifiable(products);
  }

  MarketProduct _parseProduct(Object? rawProduct, int index) {
    if (rawProduct is! Map) {
      throw FormatException(
        'Market product at index $index must be a JSON object.',
      );
    }

    final product = Map<String, dynamic>.from(rawProduct);
    final id = _readNonEmptyString(product, 'id', index);
    final categoryId = _readNonEmptyString(product, 'category', index);
    final category = _categoryFromId(categoryId, index);
    final priceMinor = product['priceMinor'];
    final currencyCode = _readNonEmptyString(product, 'currencyCode', index);
    final imageAssetPaths = _readOptionalImageAssetPaths(product, index);
    final isFeatured = product['isFeatured'] ?? false;

    if (priceMinor is! int || priceMinor < 0) {
      throw FormatException(
        'Market product at index $index has an invalid priceMinor.',
      );
    }
    if (currencyCode.length != 3 ||
        currencyCode != currencyCode.toUpperCase()) {
      throw FormatException(
        'Market product at index $index has an invalid currencyCode.',
      );
    }
    if (isFeatured is! bool) {
      throw FormatException(
        'Market product at index $index has an invalid isFeatured value.',
      );
    }

    return MarketProduct(
      id: id,
      category: category,
      price: Money(minorUnits: priceMinor, currencyCode: currencyCode),
      imageAssetPaths: imageAssetPaths,
      isFeatured: isFeatured,
    );
  }

  List<String> _readOptionalImageAssetPaths(
    Map<String, dynamic> product,
    int index,
  ) {
    final galleryValue = product['imageAssetPaths'];
    final legacyValue = product['imageAssetPath'];

    if (galleryValue != null && legacyValue != null) {
      throw FormatException(
        'Market product at index $index cannot define both imageAssetPaths '
        'and imageAssetPath.',
      );
    }

    if (galleryValue != null) {
      if (galleryValue is! List || galleryValue.isEmpty) {
        throw FormatException(
          'Market product at index $index has an invalid imageAssetPaths.',
        );
      }

      final paths = <String>[];
      final uniquePaths = <String>{};
      for (var imageIndex = 0; imageIndex < galleryValue.length; imageIndex++) {
        final value = galleryValue[imageIndex];
        if (!_isValidImageAssetPath(value)) {
          throw FormatException(
            'Market product at index $index has an invalid imageAssetPaths '
            'entry at index $imageIndex.',
          );
        }
        final path = value as String;
        if (!uniquePaths.add(path)) {
          throw FormatException(
            'Market product at index $index contains a duplicate gallery '
            'image: $path.',
          );
        }
        paths.add(path);
      }

      return List<String>.unmodifiable(paths);
    }

    if (legacyValue == null) {
      return const <String>[];
    }
    if (!_isValidImageAssetPath(legacyValue)) {
      throw FormatException(
        'Market product at index $index has an invalid imageAssetPath.',
      );
    }

    return List<String>.unmodifiable(<String>[legacyValue as String]);
  }

  bool _isValidImageAssetPath(Object? value) {
    return value is String &&
        value.startsWith('assets/market/products/') &&
        value.endsWith('.webp');
  }

  String _readNonEmptyString(
    Map<String, dynamic> product,
    String key,
    int index,
  ) {
    final value = product[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Market product at index $index has an invalid $key.',
      );
    }
    return value.trim();
  }

  MarketCategory _categoryFromId(String categoryId, int index) {
    for (final category in MarketCategory.values) {
      if (category.id == categoryId) {
        return category;
      }
    }

    throw FormatException(
      'Market product at index $index has an unknown category: $categoryId.',
    );
  }
}
