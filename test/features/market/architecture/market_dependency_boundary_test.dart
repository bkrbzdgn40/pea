import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('market stays isolated from camera, ML, Firestore, and workouts', () {
    final marketDirectory = Directory('lib/features/market');
    expect(marketDirectory.existsSync(), isTrue);

    final dartFiles = marketDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    const forbiddenDependencies = <String>[
      "package:camera/",
      "package:google_mlkit_",
      "package:cloud_firestore/",
      "/features/workout_analysis/",
      "../workout_analysis/",
    ];
    const forbiddenSecrets = <String>[
      'PAYTR_MERCHANT_KEY',
      'PAYTR_MERCHANT_SALT',
    ];

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final dependency in forbiddenDependencies) {
        if (source.contains(dependency)) {
          violations.add('${file.path}: $dependency');
        }
      }
      for (final secret in forbiddenSecrets) {
        if (source.contains(secret)) {
          violations.add('${file.path}: $secret');
        }
      }

      final importsHttp = source.contains("package:http/");
      final importsWebView = source.contains("package:webview_flutter/");
      final normalizedPath = file.path.replaceAll('\\', '/');
      final isPaymentInfrastructure = normalizedPath.contains(
        '/market/infrastructure/payments/',
      );
      final isPaymentCompositionRoot = normalizedPath.endsWith(
        '/market/presentation/providers/market_payment_session_provider.dart',
      );
      if (importsWebView && !isPaymentInfrastructure) {
        violations.add(
          '${file.path}: WebView is allowed only in payment infrastructure',
        );
      }

      if (importsHttp &&
          !isPaymentInfrastructure &&
          !isPaymentCompositionRoot) {
        violations.add(
          '${file.path}: HTTP is allowed only in payment infrastructure '
          'or its Riverpod composition root',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Market payment work must not couple itself to camera, pose, '
          'Firestore, workout-analysis, or merchant secrets. Network access '
          'must stay behind payment infrastructure. Violations: '
          '${violations.join(', ')}',
    );
  });
}
