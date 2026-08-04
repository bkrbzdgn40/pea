import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'market feature stays isolated from camera, ML, Firebase, and workouts',
    () {
      final marketDirectory = Directory('lib/features/market');
      expect(marketDirectory.existsSync(), isTrue);

      final dartFiles = marketDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      const forbiddenDependencies = <String>[
        "package:camera/",
        "package:google_mlkit_",
        "package:firebase_",
        "package:cloud_firestore/",
        "/features/workout_analysis/",
        "../workout_analysis/",
      ];

      final violations = <String>[];
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        for (final dependency in forbiddenDependencies) {
          if (source.contains(dependency)) {
            violations.add('${file.path}: $dependency');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'The market template must not couple itself to camera, pose, Firebase, '
            'or workout-analysis code. Violations: ${violations.join(', ')}',
      );
    },
  );
}
