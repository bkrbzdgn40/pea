import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled market visuals stay within the template asset budget', () {
    final directory = Directory('assets/market/products');
    expect(directory.existsSync(), isTrue);

    final catalogFile = File('assets/market/preview_catalog.json');
    expect(catalogFile.existsSync(), isTrue);

    final catalog = jsonDecode(catalogFile.readAsStringSync());
    expect(catalog, isA<Map<String, dynamic>>());

    final products = (catalog as Map<String, dynamic>)['products'];
    expect(products, isA<List<dynamic>>());

    final productEntries = (products as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(productEntries, hasLength(8));

    final referencedAssetPaths = <String>{};
    for (final product in productEntries) {
      final imageAssetPaths = product['imageAssetPaths'];
      final legacyImageAssetPath = product['imageAssetPath'];

      expect(
        imageAssetPaths == null || legacyImageAssetPath == null,
        isTrue,
        reason:
            'A product must use imageAssetPaths or imageAssetPath, not both.',
      );

      if (imageAssetPaths is List<dynamic>) {
        expect(imageAssetPaths, isNotEmpty);
        for (final path in imageAssetPaths) {
          expect(path, isA<String>());
          expect(referencedAssetPaths.add(path as String), isTrue);
        }
      } else {
        expect(legacyImageAssetPath, isA<String>());
        expect(
          referencedAssetPaths.add(legacyImageAssetPath as String),
          isTrue,
        );
      }
    }

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.webp'))
        .toList(growable: false);

    final bundledAssetPaths = files
        .map((file) => file.path.replaceAll('\\', '/'))
        .toSet();

    expect(
      bundledAssetPaths,
      unorderedEquals(referencedAssetPaths),
      reason:
          'Every bundled market image must be referenced exactly once by the '
          'catalog, with no missing or orphaned assets.',
    );

    const maximumFileBytes = 300 * 1024;
    const maximumTotalBytes = 2 * 1024 * 1024;
    var totalBytes = 0;

    for (final file in files) {
      final bytes = file.readAsBytesSync();
      totalBytes += bytes.length;

      expect(
        bytes.length,
        lessThanOrEqualTo(maximumFileBytes),
        reason: '${file.path} exceeds the per-image budget.',
      );
      expect(bytes.length, greaterThanOrEqualTo(12));
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(bytes.sublist(8, 12)), 'WEBP');
    }

    expect(
      totalBytes,
      lessThanOrEqualTo(maximumTotalBytes),
      reason: 'Market product visuals exceed the total 2 MB budget.',
    );
  });
}
