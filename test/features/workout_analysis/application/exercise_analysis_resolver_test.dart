import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_analysis_resolver.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const resolver = ExerciseAnalysisResolver();

  group('ExerciseAnalysisResolver', () {
    test('returns null for a null selection', () {
      expect(resolver.resolveActiveExercise(null), isNull);
    });

    test('keeps supported selections on their canonical exercise type', () {
      expect(
        resolver.resolveActiveExercise(ExerciseType.squat),
        ExerciseType.squat,
      );
      expect(
        resolver.resolveActiveExercise(ExerciseType.plank),
        ExerciseType.plank,
      );
      expect(
        resolver.resolveActiveExercise(ExerciseType.pushUp),
        ExerciseType.pushUp,
      );
      expect(
        resolver.resolveActiveExercise(ExerciseType.sitUp),
        ExerciseType.sitUp,
      );
    });

    test('returns null for unsupported selections', () {
      for (final type in const <ExerciseType>[ExerciseType.lunge]) {
        expect(resolver.resolveActiveExercise(type), isNull);
      }
    });
  });
}
