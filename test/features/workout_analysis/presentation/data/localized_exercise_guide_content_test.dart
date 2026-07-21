import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/data/exercise_guide_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/data/localized_exercise_guide_content.dart';

void main() {
  const catalog = ExerciseGuideCatalog();

  test(
    'keeps corrected Turkish guide copy and localizes English guide copy',
    () {
      final source = catalog.contentFor(ExerciseType.hollowHold);
      final turkish = localizedExerciseGuideContent(
        content: source,
        isTurkish: true,
      );
      final english = localizedExerciseGuideContent(
        content: source,
        isTurkish: false,
      );

      expect(turkish.setupSteps.join(' '), contains('Sırt üstü uzan'));
      expect(turkish.tips.join(' '), contains('Kolları kulaklara yakın uzat'));
      expect(english.subtitle, contains('core tension'));
      expect(english.setupSteps.join(' '), contains('Lie on your back'));
      expect(english.youtubeUrl, source.youtubeUrl);
      expect(english.difficulty, source.difficulty);
    },
  );

  test('provides English guide copy for every canonical exercise', () {
    for (final type in ExerciseType.values) {
      final source = catalog.contentFor(type);
      final english = localizedExerciseGuideContent(
        content: source,
        isTurkish: false,
      );

      expect(english.type, type);
      expect(english.subtitle, isNotEmpty);
      expect(english.purpose, isNotEmpty);
      expect(english.setupSteps, isNotEmpty);
      expect(english.tips, isNotEmpty);
      expect(english.commonMistakes, isNotEmpty);
    }
  });
}
