import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_progress.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const catalog = ChallengeCatalog();
  final pushUp = catalog.definitionFor(ExerciseType.pushUp);

  group('ChallengeProgress', () {
    test('exposes next medal and remaining trusted volume', () {
      final progress = ChallengeProgress(
        definition: pushUp,
        period: ChallengePeriod.daily,
        value: 12,
      );

      expect(progress.tier, MedalTier.bronze);
      expect(progress.nextTier, MedalTier.silver);
      expect(progress.nextThreshold, 20);
      expect(progress.remainingToNextTier, 8);
      expect(progress.hasReachedGold, isFalse);
    });

    test('stops applying numeric pressure after gold', () {
      final progress = ChallengeProgress(
        definition: pushUp,
        period: ChallengePeriod.daily,
        value: 35,
      );

      expect(progress.tier, MedalTier.gold);
      expect(progress.nextTier, isNull);
      expect(progress.nextThreshold, isNull);
      expect(progress.remainingToNextTier, isNull);
      expect(progress.hasReachedGold, isTrue);
    });

    test('rejects invalid accumulated values', () {
      expect(
        () => ChallengeProgress(
          definition: pushUp,
          period: ChallengePeriod.daily,
          value: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ChallengeProgress(
          definition: pushUp,
          period: ChallengePeriod.daily,
          value: double.nan,
        ),
        throwsArgumentError,
      );
    });
  });
}
