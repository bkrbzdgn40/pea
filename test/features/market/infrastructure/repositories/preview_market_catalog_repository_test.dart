import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/market/domain/models/market_category.dart';
import 'package:pose_estimation_app/features/market/infrastructure/repositories/preview_market_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the deterministic bundled preview catalog', () async {
    final repository = PreviewMarketCatalogRepository();

    final products = await repository.loadProducts();

    expect(products, hasLength(8));
    expect(products.map((product) => product.id).toSet(), hasLength(8));
    expect(products.every((product) => product.price.minorUnits > 0), isTrue);
    expect(
      products.every(
        (product) => product.imageAssetPath?.endsWith('.webp') ?? false,
      ),
      isTrue,
    );
    expect(
      products.map((product) => product.imageAssetPath).toSet(),
      hasLength(8),
    );
    expect(
      products.any((product) => product.category == MarketCategory.setup),
      isTrue,
    );
    expect(
      products.any((product) => product.category == MarketCategory.mobility),
      isTrue,
    );
    expect(
      products.where((product) => product.category == MarketCategory.apparel),
      hasLength(2),
    );
  });

  test('rejects duplicate product ids in the catalog contract', () async {
    final repository = PreviewMarketCatalogRepository(
      bundle: _StringAssetBundle(
        jsonEncode({
          'schemaVersion': 1,
          'products': [
            {
              'id': 'duplicate',
              'category': 'strength',
              'priceMinor': 100,
              'currencyCode': 'TRY',
            },
            {
              'id': 'duplicate',
              'category': 'mobility',
              'priceMinor': 200,
              'currencyCode': 'TRY',
            },
          ],
        }),
      ),
    );

    await expectLater(repository.loadProducts(), throwsFormatException);
  });

  test('rejects image assets outside the market product directory', () async {
    final repository = PreviewMarketCatalogRepository(
      bundle: _StringAssetBundle(
        jsonEncode({
          'schemaVersion': 1,
          'products': [
            {
              'id': 'unsafe_image',
              'category': 'strength',
              'priceMinor': 100,
              'currencyCode': 'TRY',
              'imageAssetPath': 'assets/config/exercises/private.png',
            },
          ],
        }),
      ),
    );

    await expectLater(repository.loadProducts(), throwsFormatException);
  });

  test('rejects unsupported catalog schema versions', () async {
    final repository = PreviewMarketCatalogRepository(
      bundle: _StringAssetBundle(
        jsonEncode({'schemaVersion': 99, 'products': const <Object>[]}),
      ),
    );

    await expectLater(repository.loadProducts(), throwsFormatException);
  });
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
  }
}
