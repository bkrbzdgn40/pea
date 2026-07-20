import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_analysis_resolver.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const resolver = ExerciseAnalysisResolver();

  group('ExerciseAnalysisResolver', () {
    test('returns null for a null selection', () {
      expect(resolver.resolveActiveExercise(null), isNull);
    });

    test('keeps every supported selection on its canonical exercise type', () {
      for (final type in ExerciseType.values) {
        expect(resolver.resolveActiveExercise(type), type, reason: type.name);
      }
    });
  });
}
