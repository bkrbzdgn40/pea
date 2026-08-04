import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled market visuals stay within the template asset budget', () {
    final directory = Directory('assets/market/products');
    expect(directory.existsSync(), isTrue);

    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.webp'))
        .toList(growable: false);

    expect(files, hasLength(8));

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
