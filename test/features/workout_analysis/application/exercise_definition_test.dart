import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const catalog = ExerciseCatalog();

  group('ExerciseDefinition.analysisExercise', () {
    test('returns the canonical type for supported definitions', () {
      for (final type in const <ExerciseType>[
        ExerciseType.squat,
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.pushUp,
        ExerciseType.sitUp,
      ]) {
        final definition = catalog.definitionFor(type);

        expect(definition.analysisExercise, definition.type);
      }
    });

    test('throws StateError for unsupported definitions', () {
      for (final type in const <ExerciseType>[ExerciseType.lunge]) {
        final definition = catalog.definitionFor(type);

        expect(() => definition.analysisExercise, throwsA(isA<StateError>()));
      }
    });
  });
}
