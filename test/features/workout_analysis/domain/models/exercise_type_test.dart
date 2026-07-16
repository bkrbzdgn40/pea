import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('ExerciseType', () {
    test('keeps stable ids and titles', () {
      expect(ExerciseType.squat.id, 'squat');
      expect(ExerciseType.squat.title, 'Squat');
      expect(ExerciseType.plank.id, 'plank');
      expect(ExerciseType.plank.title, 'Plank');
      expect(ExerciseType.lunge.id, 'lunge');
      expect(ExerciseType.lunge.title, 'Lunge');
      expect(ExerciseType.pushUp.id, 'push_up');
      expect(ExerciseType.pushUp.title, 'Push-up');
      expect(ExerciseType.sitUp.id, 'sit_up');
      expect(ExerciseType.sitUp.title, 'Sit-up');
      expect(ExerciseType.bicepsCurl.id, 'biceps_curl');
      expect(ExerciseType.bicepsCurl.title, 'Biceps Curl');
    });

    test('fromIdOrNull resolves every canonical exercise id', () {
      for (final type in ExerciseType.values) {
        expect(ExerciseType.fromIdOrNull(type.id), type);
      }
    });

    test('fromIdOrNull returns null for unknown ids', () {
      expect(ExerciseType.fromIdOrNull('burpee'), isNull);
    });

    test('fromId throws for unknown ids', () {
      expect(
        () => ExerciseType.fromId('burpee'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
