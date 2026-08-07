import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_volume_profile.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const catalog = ChallengeCatalog();

  group('ChallengeCatalog', () {
    test('covers every supported exercise exactly once', () {
      expect(catalog.definitions, hasLength(ExerciseType.values.length));
      expect(
        catalog.definitions
            .map((definition) => definition.exerciseType)
            .toSet(),
        ExerciseType.values.toSet(),
      );
      expect(
        catalog.definitions.map((definition) => definition.id).toSet(),
        hasLength(ExerciseType.values.length),
      );
      expect(
        catalog.definitions.every(
          (definition) => definition.catalogVersion == ChallengeCatalog.version,
        ),
        isTrue,
      );
    });

    test('locks push-up thresholds to the product contract', () {
      final definition = catalog.definitionFor(ExerciseType.pushUp);

      expect(definition.id, 'push_up_volume');
      expect(definition.profile, ChallengeVolumeProfile.r2Standard);
      expect(definition.metric, ChallengeMetric.validRepetitions);
      expect(definition.thresholdsFor(ChallengePeriod.daily).bronze, 10);
      expect(definition.thresholdsFor(ChallengePeriod.daily).silver, 20);
      expect(definition.thresholdsFor(ChallengePeriod.daily).gold, 30);
      expect(definition.thresholdsFor(ChallengePeriod.weekly).gold, 210);
      expect(definition.thresholdsFor(ChallengePeriod.monthly).gold, 600);
    });

    test('uses hold seconds only for the four hold exercises', () {
      const expectedHoldExercises = <ExerciseType>{
        ExerciseType.plank,
        ExerciseType.hollowHold,
        ExerciseType.wallSit,
        ExerciseType.sidePlank,
      };

      final actual = catalog.definitions
          .where(
            (definition) =>
                definition.metric == ChallengeMetric.trustedHoldSeconds,
          )
          .map((definition) => definition.exerciseType)
          .toSet();

      expect(actual, expectedHoldExercises);
    });

    test('supports lookup by exercise id and stable challenge id', () {
      final byExercise = catalog.definitionForExerciseId('squat');
      final byChallenge = catalog.definitionForId('squat_volume');

      expect(byExercise, isNotNull);
      expect(identical(byExercise, byChallenge), isTrue);
      expect(catalog.definitionForExerciseId('unknown'), isNull);
      expect(catalog.definitionForId('unknown_volume'), isNull);
    });
  });
}
