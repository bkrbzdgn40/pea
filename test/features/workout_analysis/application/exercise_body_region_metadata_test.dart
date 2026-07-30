import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_definition_metadata.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  test('assigns every exercise to exactly one discovery body region', () {
    final assignments = <ExerciseType, ExerciseBodyRegion>{
      for (final exercise in ExerciseType.values) exercise: exercise.bodyRegion,
    };

    expect(assignments.length, ExerciseType.values.length);
    expect(assignments.values.toSet(), ExerciseBodyRegion.values.toSet());
  });

  test('keeps representative exercises in user-facing categories', () {
    expect(ExerciseType.bicepsCurl.bodyRegion, ExerciseBodyRegion.upperBody);
    expect(ExerciseType.shoulderPress.bodyRegion, ExerciseBodyRegion.upperBody);
    expect(ExerciseType.squat.bodyRegion, ExerciseBodyRegion.lowerBody);
    expect(ExerciseType.plank.bodyRegion, ExerciseBodyRegion.core);
    expect(ExerciseType.jumpingJack.bodyRegion, ExerciseBodyRegion.fullBody);
  });
}
