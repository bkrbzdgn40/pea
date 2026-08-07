import 'dart:async';

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

import '../../../../support/presentation_test_support.dart';
import '../../../../support/presentation_test_harness.dart';

void main() {
  testWidgets(
    'shows the shared loading state while achievements are unresolved',
    (WidgetTester tester) async {
      final completer = Completer<AchievementsState>();

      await pumpTestApp(
        tester,
        home: const AchievementsScreen(),
        overrides: [
          achievementsProvider.overrideWith((ref) => completer.future),
        ],
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        const AchievementsState(
          source: AchievementsDataSource.real,
          achievements: <Achievement>[
            Achievement(
              id: 'first_reliable_analysis',
              title: 'Guvenilir Baslangic',
              description: 'Ilk guvenilir hareket analizini tamamla.',
              isUnlocked: true,
              progress: 1,
              requirementText: 'Ilk guvenilir analizini tamamla',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Güvenilir Başlangıç'), findsOneWidget);
    },
  );

  testWidgets('shows the shared error state when achievements fail', (
    WidgetTester tester,
  ) async {
    final completer = Completer<AchievementsState>();

    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [achievementsProvider.overrideWith((ref) => completer.future)],
    );
    await tester.pump();

    completer.completeError(Exception('boom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Başarılar yüklenemedi. Lütfen daha sonra tekrar dene.'),
      findsOneWidget,
    );
  });

  testWidgets('shows earned first and only one meaningful next achievement', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
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
              const Achievement(
                id: 'exercise_explorer_3',
                title: 'Hareket Kasifi',
                description: 'Farkli hareketleri kesfet.',
                isUnlocked: false,
                progress: 2 / 3,
                current: 2,
                target: 3,
                requirementText: '2 / 3 farkli egzersiz',
              ),
              const Achievement(
                id: 'reliable_sessions_5',
                title: 'Saglam Temel',
                description: 'Guvenilir oturumlar.',
                isUnlocked: false,
                progress: 0.4,
                current: 2,
                target: 5,
                requirementText: '2 / 5 guvenilir oturum',
              ),
            ],
            recommendedAchievement: const Achievement(
              id: 'exercise_explorer_3',
              title: 'Hareket Kasifi',
              description: 'Farkli hareketleri kesfet.',
              isUnlocked: false,
              progress: 2 / 3,
              current: 2,
              target: 3,
              requirementText: '2 / 3 farkli egzersiz',
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Kazanılanlar · 1'), findsOneWidget);
    expect(find.text('Güvenilir Başlangıç'), findsOneWidget);
    expect(find.byKey(const ValueKey('next-achievement-card')), findsOneWidget);
    expect(find.text('Bir farklı egzersiz daha'), findsOneWidget);
    expect(find.text('Kilitli'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
  });

  testWidgets('reward history combines medals and achievements with filters', (
    WidgetTester tester,
  ) async {
    final achievementReward = _achievementReward();
    final medalReward = _medalReward();

    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
            source: AchievementsDataSource.real,
            achievements: const <Achievement>[],
            rewards: [medalReward, achievementReward],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('reward-history-view-button')));
    await tester.pumpAndSettle();

    expect(find.text('Ödül geçmişi'), findsWidgets);
    expect(find.text('Şınav · Günlük Gümüş'), findsOneWidget);
    expect(find.text('Güvenilir Başlangıç'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reward-filter-medals')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reward-period-daily')), findsOneWidget);
    expect(find.text('Güvenilir Başlangıç'), findsNothing);
    expect(find.text('Şınav · Günlük Gümüş'), findsOneWidget);
  });

  testWidgets(
    'empty signed-in presentation has a next step without badge wall',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const AchievementsScreen(),
        overrides: [
          achievementsProvider.overrideWith(
            (ref) => const AchievementsState(
              source: AchievementsDataSource.empty,
              achievements: <Achievement>[
                Achievement(
                  id: 'first_reliable_analysis',
                  title: 'Guvenilir Baslangic',
                  description: 'Ilk guvenilir hareket analizini tamamla.',
                  isUnlocked: false,
                  progress: 0,
                  current: 0,
                  target: 1,
                  requirementText: 'Ilk guvenilir analizini tamamla',
                ),
              ],
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Henüz kazanılmış başarım yok'), findsOneWidget);
      expect(find.text('Sıradaki başarım'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('next-achievement-card')),
        findsOneWidget,
      );
      expect(find.text('Kilitli'), findsNothing);
    },
  );
  testWidgets('compact layout tolerates 1.3 text scale without overflow', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 1.3,
      ),
      overrides: [
        achievementsProvider.overrideWith(
          (ref) => AchievementsState(
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
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expectNoPresentationExceptions(tester);

    final nextAchievementCard = find.byKey(
      const ValueKey('next-achievement-card'),
    );
    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      nextAchievementCard,
      220,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

    expect(nextAchievementCard, findsOneWidget);
    expectNoPresentationExceptions(tester);
  });

  testWidgets('reward navigation controls keep accessible touch targets', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AchievementsScreen(),
      overrides: [
        achievementsProvider.overrideWith((ref) => _releaseAssuranceState()),
      ],
    );
    await tester.pumpAndSettle();

    final achievementsButton = find.byKey(
      const ValueKey<String>('achievements-view-button'),
    );
    final historyButton = find.byKey(
      const ValueKey<String>('reward-history-view-button'),
    );
    expect(tester.getSize(achievementsButton).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(historyButton).height, greaterThanOrEqualTo(48));

    await tester.tap(historyButton);
    await tester.pumpAndSettle();
    final medalFilter = find.byKey(
      const ValueKey<String>('reward-filter-medals'),
    );
    expect(tester.getSize(medalFilter).height, greaterThanOrEqualTo(48));
  });
  testWidgetsAcrossPresentationMatrix(
    'achievement view remains overflow-free across the release matrix',
    PresentationTestMatrix.critical,
    (tester, configuration) async {
      await pumpTestApp(
        tester,
        home: const AchievementsScreen(),
        configuration: configuration,
        overrides: [
          achievementsProvider.overrideWith((ref) => _releaseAssuranceState()),
        ],
      );
      await tester.pumpAndSettle();
      expectNoPresentationExceptions(tester);

      final list = find.byKey(
        const PageStorageKey<String>('achievements-content'),
      );
      for (var index = 0; index < 4; index++) {
        await tester.fling(list, const Offset(0, -360), 900);
        await tester.pumpAndSettle();
        expectNoPresentationExceptions(tester);
      }
    },
  );

  testWidgets(
    'reward history tolerates compact portrait with 2x text and reduced motion',
    (tester) async {
      await pumpTestApp(
        tester,
        home: const AchievementsScreen(
          initialView: AchievementsView.rewardHistory,
        ),
        configuration: const PresentationTestConfiguration(
          viewport: PresentationTestViewport.compactPortrait,
          textScaleFactor: 2,
          disableAnimations: true,
        ),
        overrides: [
          achievementsProvider.overrideWith((ref) => _releaseAssuranceState()),
        ],
      );
      await tester.pumpAndSettle();
      expectNoPresentationExceptions(tester);

      final list = find.byKey(
        const PageStorageKey<String>('achievements-content'),
      );
      for (var index = 0; index < 4; index++) {
        await tester.fling(list, const Offset(0, -320), 800);
        await tester.pumpAndSettle();
        expectNoPresentationExceptions(tester);
      }
    },
  );
}

AchievementsState _releaseAssuranceState() {
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
    rewards: [_medalReward(), _achievementReward()],
  );
}

AchievementReward _achievementReward() {
  final at = DateTime.utc(2026, 8, 4, 9);
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

ChallengeMedalReward _medalReward() {
  final bronzeAt = DateTime.utc(2026, 8, 6, 9);
  final silverAt = DateTime.utc(2026, 8, 6, 10);
  return ChallengeMedalReward(
    ownerId: 'owner-1',
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    period: ChallengePeriod.daily,
    periodKey: '2026-08-06',
    timezoneOffset: const Duration(hours: 3),
    highestTier: MedalTier.silver,
    progressValueAtHighestTier: 20,
    thresholdsAtAward: MedalThresholds(bronze: 10, silver: 20, gold: 30),
    tierEarnedAt: <MedalTier, DateTime>{
      MedalTier.bronze: bronzeAt,
      MedalTier.silver: silverAt,
    },
    qualifyingEventId: 'session-20',
    isBackfilled: false,
    createdAt: bronzeAt,
    updatedAt: silverAt,
  );
}
