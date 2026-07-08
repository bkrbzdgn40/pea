import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_analysis_resolver.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const resolver = ExerciseAnalysisResolver();

  group('ExerciseAnalysisResolver', () {
    test('keeps squat as the active analysis exercise', () {
      expect(
        resolver.resolveActiveExercise(ExerciseType.squat),
        ExerciseType.squat,
      );
    });

    test('keeps plank as the active analysis exercise', () {
      expect(
        resolver.resolveActiveExercise(ExerciseType.plank),
        ExerciseType.plank,
      );
    });

    test('returns null for unsupported selections', () {
      for (final exercise in const [
        ExerciseType.lunge,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
      ]) {
        expect(resolver.resolveActiveExercise(exercise), isNull);
      }
    });
  });
}
