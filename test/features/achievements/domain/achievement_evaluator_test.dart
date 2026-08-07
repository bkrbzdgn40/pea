import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_catalog.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_evaluator.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_body_region.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_facts.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const evaluator = AchievementEvaluator();

  test('reliable session achievements use distinct ids and exercises', () {
    final facts = AchievementFacts(
      reliableSessionIds: const {'a', 'b', 'c', 'd', 'e'},
      reliableExerciseTypes: const {
        ExerciseType.squat,
        ExerciseType.pushUp,
        ExerciseType.plank,
      },
    );

    expect(
      evaluator
          .evaluate(AchievementCatalog.firstReliableAnalysis, facts)
          .isUnlocked,
      isTrue,
    );
    expect(
      evaluator
          .evaluate(AchievementCatalog.reliableSessions5, facts)
          .isUnlocked,
      isTrue,
    );
    expect(
      evaluator
          .evaluate(AchievementCatalog.exerciseExplorer3, facts)
          .isUnlocked,
      isTrue,
    );
  });

  test('guide requires all six canonical steps and ignores unknown steps', () {
    final incomplete = evaluator.evaluate(
      AchievementCatalog.guideCompleted,
      const AchievementFacts(
        openedGuideStepIds: {'1', '2', '3', '4', '5', 'x'},
      ),
    );
    final complete = evaluator.evaluate(
      AchievementCatalog.guideCompleted,
      const AchievementFacts(
        openedGuideStepIds: {'1', '2', '3', '4', '5', '6'},
      ),
    );

    expect(incomplete.isUnlocked, isFalse);
    expect(incomplete.current, 5);
    expect(complete.isUnlocked, isTrue);
  });

  test('balanced explorer requires lower upper and core, not full body', () {
    final onlyTwo = evaluator.evaluate(
      AchievementCatalog.balancedExplorer,
      const AchievementFacts(
        reliableBodyRegions: {
          AchievementBodyRegion.lowerBody,
          AchievementBodyRegion.upperBody,
          AchievementBodyRegion.fullBody,
        },
      ),
    );
    final allThree = evaluator.evaluate(
      AchievementCatalog.balancedExplorer,
      const AchievementFacts(
        reliableBodyRegions: {
          AchievementBodyRegion.lowerBody,
          AchievementBodyRegion.upperBody,
          AchievementBodyRegion.core,
        },
      ),
    );

    expect(onlyTwo.current, 2);
    expect(onlyTwo.isUnlocked, isFalse);
    expect(allThree.isUnlocked, isTrue);
  });

  test(
    'planned workout ids are unique and support first and fifth milestones',
    () {
      final facts = AchievementFacts(
        completedPlanRunIds: const {'p1', 'p2', 'p3', 'p4', 'p5'},
      );

      expect(
        evaluator
            .evaluate(AchievementCatalog.plannedWorkoutCompleted, facts)
            .isUnlocked,
        isTrue,
      );
      expect(
        evaluator
            .evaluate(AchievementCatalog.plannedWorkouts5, facts)
            .isUnlocked,
        isTrue,
      );
    },
  );

  test('return achievement needs at least fourteen empty local days', () {
    final tooSoon = evaluator.evaluate(
      AchievementCatalog.returnAfter14Days,
      const AchievementFacts(
        qualifiedLocalDayKeys: {'2026-01-01', '2026-01-15'},
      ),
    );
    final qualifies = evaluator.evaluate(
      AchievementCatalog.returnAfter14Days,
      const AchievementFacts(
        qualifiedLocalDayKeys: {'2026-01-01', '2026-01-16'},
      ),
    );

    expect(tooSoon.isUnlocked, isFalse);
    expect(qualifies.isUnlocked, isTrue);
  });

  test('rhythm uses local day keys and finds longest consecutive run', () {
    final days = <String>{
      for (var day = 1; day <= 30; day += 1)
        '2026-06-${day.toString().padLeft(2, '0')}',
    };
    final result = evaluator.evaluate(
      AchievementCatalog.rhythm30Days,
      AchievementFacts(qualifiedLocalDayKeys: days),
    );

    expect(result.isUnlocked, isTrue);
    expect(result.current, 30);
  });

  test('golden week requires three distinct exercises in the same week', () {
    final result = evaluator.evaluate(
      AchievementCatalog.goldenWeek,
      const AchievementFacts(
        weeklyMedalExerciseIdsByWeek: {
          '2026-08-03': {
            ExerciseType.squat,
            ExerciseType.pushUp,
            ExerciseType.plank,
          },
        },
      ),
    );

    expect(result.isUnlocked, isTrue);
  });

  test('invalid local day keys fail loudly instead of corrupting streaks', () {
    expect(
      () => evaluator.evaluate(
        AchievementCatalog.rhythm30Days,
        const AchievementFacts(qualifiedLocalDayKeys: {'2026-02-31'}),
      ),
      throwsFormatException,
    );
  });
}
