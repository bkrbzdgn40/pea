import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';

void main() {
  test(
    'current exercise validation matrix matches the runtime catalog ids',
    () {
      final matrix = File('docs/current_exercise_validation_matrix.md');

      expect(matrix.existsSync(), isTrue);

      final contents = matrix.readAsStringSync();
      final documentedIds = RegExp(
        r'^\| `([^`]+)` \|',
        multiLine: true,
      ).allMatches(contents).map((match) => match.group(1)!).toList();
      const catalog = ExerciseCatalog();
      final runtimeIds = catalog.definitions
          .where((definition) => definition.isAnalysisSupported)
          .map((definition) => definition.id)
          .toList(growable: false);

      expect(documentedIds, hasLength(runtimeIds.length));
      expect(documentedIds.toSet(), hasLength(documentedIds.length));
      expect(documentedIds, unorderedEquals(runtimeIds));
      expect(contents, contains('pose_estimation_app.tar(167).gz'));
      expect(contents, contains('Canonical hareket sayısı: **34**'));
      expect(contents, contains('Range-rep hareket: **30**'));
      expect(contents, contains('Hold hareket: **4**'));
    },
  );
}
