import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_thresholds.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/challenge_medal_reward.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

const _runGoldens = bool.fromEnvironment('RUN_GOLDENS');

void main() {
  testWidgets('dark achievements release golden', (tester) async {
    await _pumpGolden(tester, const AchievementsScreen());

    await expectLater(
      find.byKey(const ValueKey<String>('golden-achievements-root')),
      matchesGoldenFile('goldens/achievements_dark.png'),
    );
  }, skip: !_runGoldens);

  testWidgets('dark reward history release golden', (tester) async {
    await _pumpGolden(
      tester,
      const AchievementsScreen(initialView: AchievementsView.rewardHistory),
    );

    await expectLater(
      find.byKey(const ValueKey<String>('golden-achievements-root')),
      matchesGoldenFile('goldens/reward_history_dark.png'),
    );
  }, skip: !_runGoldens);
}

Future<void> _pumpGolden(WidgetTester tester, Widget screen) async {
  await pumpTestApp(
    tester,
    configuration: const PresentationTestConfiguration(
      viewport: PresentationTestViewport.standardPortrait,
      disableAnimations: true,
    ),
    home: RepaintBoundary(
      key: const ValueKey<String>('golden-achievements-root'),
      child: screen,
    ),
    overrides: [achievementsProvider.overrideWith((ref) => _goldenState())],
  );
  await tester.pumpAndSettle();
}

AchievementsState _goldenState() {
  return AchievementsState(
    source: AchievementsDataSource.real,
    achievements: [
      Achievement(
        id: 'first_reliable_analysis',
        title: 'Guvenilir Baslangic',
        description: 'Ilk guvenilir hareket analizini tamamla.',
        isUnlocked: true,
        progress: 1,
        current: 1,
        target: 1,
        unlockedAtUtc: DateTime.utc(2026, 8, 6, 10),
        requirementText: 'Ilk guvenilir analizini tamamla',
      ),
      Achievement(
        id: 'golden_week',
        title: 'Altin Hafta',
        description: 'Bir haftada uc farkli egzersizde madalya kazan.',
        isUnlocked: true,
        progress: 1,
        current: 3,
        target: 3,
        unlockedAtUtc: DateTime.utc(2026, 8, 5, 10),
        requirementText: '3 / 3',
        isSecret: true,
      ),
      const Achievement(
        id: 'exercise_explorer_3',
        title: 'Hareket Kasifi',
        description: 'Farkli hareketleri guvenilir analizlerle kesfet.',
        isUnlocked: false,
        progress: 2 / 3,
        current: 2,
        target: 3,
        requirementText: '2 / 3 farkli egzersiz',
      ),
    ],
    recommendedAchievement: const Achievement(
      id: 'exercise_explorer_3',
      title: 'Hareket Kasifi',
      description: 'Farkli hareketleri guvenilir analizlerle kesfet.',
      isUnlocked: false,
      progress: 2 / 3,
      current: 2,
      target: 3,
      requirementText: '2 / 3 farkli egzersiz',
    ),
    rewards: [_goldMedalReward(), _achievementReward()],
  );
}

AchievementReward _achievementReward() {
  final at = DateTime.utc(2026, 8, 6, 10);
  return AchievementReward(
    ownerId: 'owner-1',
    achievementId: 'first_reliable_analysis',
    definitionVersion: 1,
    unlockedAt: at,
    qualifyingEventId: 'session-1',
    isBackfilled: false,
    createdAt: at,
    updatedAt: at,
  );
}

ChallengeMedalReward _goldMedalReward() {
  final bronzeAt = DateTime.utc(2026, 8, 7, 8);
  final silverAt = DateTime.utc(2026, 8, 7, 9);
  final goldAt = DateTime.utc(2026, 8, 7, 10);
  return ChallengeMedalReward(
    ownerId: 'owner-1',
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    period: ChallengePeriod.daily,
    periodKey: '2026-08-07',
    timezoneOffset: const Duration(hours: 3),
    highestTier: MedalTier.gold,
    progressValueAtHighestTier: 30,
    thresholdsAtAward: MedalThresholds(bronze: 10, silver: 20, gold: 30),
    tierEarnedAt: <MedalTier, DateTime>{
      MedalTier.bronze: bronzeAt,
      MedalTier.silver: silverAt,
      MedalTier.gold: goldAt,
    },
    qualifyingEventId: 'session-30',
    isBackfilled: false,
    createdAt: bronzeAt,
    updatedAt: goldAt,
  );
}
