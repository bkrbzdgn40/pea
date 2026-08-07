import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/rewards/domain/models/achievement_reward.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_statistics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_score_trend_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_achievement_showcase_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/analytics_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/how_to_use_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/home_task_surface.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('keeps Home focused on the three analysis actions', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith((ref) => _mixedDashboardData()),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
      ],
    );
    await tester.pump();

    expect(find.text('Analize Başla'), findsOneWidget);
    expect(find.text('Seçili hareket: Plank'), findsOneWidget);
    expect(find.text('Planlı Antrenman'), findsOneWidget);
    expect(find.text('Kamera Ölçümü'), findsOneWidget);
    expect(find.text('Aktif Hedef'), findsNothing);
    expect(find.text('Toplam Analiz'), findsNothing);
    expect(find.text('Bu Hafta'), findsNothing);
    expect(find.text('Son Oturum'), findsNothing);
    expect(find.text('İçgörü'), findsNothing);
    expect(find.text('Yeni başarı'), findsNothing);
    expect(find.byKey(const ValueKey('home-insight-card')), findsNothing);
    expect(find.byKey(const ValueKey('home-progress-panel')), findsNothing);
    expect(find.byKey(const ValueKey('home-active-goal')), findsNothing);
    expect(find.byKey(const Key('exercise-distribution-card')), findsNothing);
  });

  testWidgets('shows grouped exercises as a single Other slice in Analytics', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AnalyticsScreen(),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) => const HomeDashboardData(
            totalAnalyses: 10,
            averageScore: 84,
            thisWeekCount: 2,
            bestScore: 91,
            scoreTrend: <ScoreTrendPoint>[],
            exerciseDistribution: [
              ExerciseDistributionItem(
                label: 'Squat',
                value: 40,
                exerciseId: 'squat',
              ),
              ExerciseDistributionItem(
                label: 'Plank',
                value: 30,
                exerciseId: 'plank',
              ),
              ExerciseDistributionItem(
                label: 'Diğer',
                value: 30,
                groupedExerciseCount: 3,
              ),
            ],
            source: HomeDashboardSource.real,
          ),
        ),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        exerciseScoreTrendProvider(ExerciseType.plank).overrideWith(
          (ref) async => ExerciseScoreTrendData(
            exercise: ExerciseType.plank,
            samples: [
              WorkoutScoreSample(startedAt: DateTime(2026, 8, 1), score: 82),
            ],
            source: UserSessionsSnapshotSource.real,
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('score-trend-card')), findsOneWidget);
    final otherItem = find.byKey(const Key('exercise-distribution-item-other'));
    expect(otherItem, findsOneWidget);
    expect(find.text('Diğer (3)'), findsOneWidget);

    await tester.ensureVisible(otherItem);
    await tester.pump();
    await tester.tap(otherItem);
    await tester.pump();

    expect(find.text('Diğer (3)'), findsNWidgets(2));
    expect(find.byKey(const Key('score-trend-card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gives each time period a distinct greeting surface', (
    WidgetTester tester,
  ) async {
    final cases = <(int, String, String)>[
      (8, 'home-greeting-morning', 'Günaydın'),
      (13, 'home-greeting-afternoon', 'İyi öğlenler'),
      (19, 'home-greeting-evening', 'İyi akşamlar'),
      (23, 'home-greeting-night', 'İyi geceler'),
    ];

    for (final testCase in cases) {
      await pumpTestApp(tester, home: HomeGreetingHeader(hour: testCase.$1));
      await tester.pump();

      expect(find.byKey(ValueKey(testCase.$2)), findsOneWidget);
      expect(find.text(testCase.$3), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-greeting-symbol')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps the greeting entrance visible long enough to notice', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const HomeGreetingHeader(hour: 8));
    await tester.pump();

    final opacityFinder = find.byKey(
      const ValueKey('home-greeting-symbol-opacity'),
    );
    expect(opacityFinder, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    final halfwayOpacity = tester.widget<Opacity>(opacityFinder).opacity;
    expect(halfwayOpacity, greaterThan(0.35));
    expect(halfwayOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
  });

  testWidgets('keeps recent sessions and dashboard metrics off Home', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) => HomeDashboardData(
            totalAnalyses: 8,
            averageScore: 87,
            thisWeekCount: 3,
            bestScore: 93,
            scoreTrend: const <ScoreTrendPoint>[],
            exerciseDistribution: const <ExerciseDistributionItem>[],
            source: HomeDashboardSource.real,
            latestSession: _latestRangeSession(),
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Son Oturum'), findsNothing);
    expect(find.text('Oturumu Aç'), findsNothing);
    expect(find.text('Toplam Analiz'), findsNothing);
    expect(find.text('Bu Hafta'), findsNothing);
    expect(find.text('Ortalama Skor'), findsNothing);
  });

  testWidgets(
    'keeps drawer-owned destinations out of the Home action surface',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const HomeScreen(),
        overrides: [
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        ],
      );
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));

      expect(appBar.actions, isNotEmpty);
      expect(
        find.byKey(const ValueKey('home-how-to-use-action')),
        findsOneWidget,
      );
      expect(find.text('Hareketi Değiştir'), findsNothing);
      expect(find.byKey(const ValueKey('home-primary-action')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-planned-workout-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-assessment-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps the greeting focused without the analysis badge', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const HomeGreetingHeader(hour: 8));
    await tester.pump();

    expect(find.text('KAMERA TABANLI HAREKET ANALİZİ'), findsNothing);
    expect(find.text('Günaydın'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-greeting-symbol')), findsOneWidget);
  });

  testWidgets('opens How to Use from the restrained Home app bar action', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const HomeScreen());
    await tester.pump();

    final action = find.byKey(const ValueKey('home-how-to-use-action'));
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.byType(HowToUseScreen), findsOneWidget);
    expect(find.text('Nasıl Kullanılır'), findsOneWidget);
  });

  testWidgets('renders the prominent start action and stylized quick flows', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(tester, home: const HomeScreen());
    await tester.pump();

    expect(find.byKey(const ValueKey('home-primary-action')), findsOneWidget);
    expect(find.text('Analize Başla'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-planned-workout-action')),
        matching: find.byIcon(Icons.fitness_center_rounded),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-assessment-action')),
        matching: find.byIcon(Icons.center_focus_strong_rounded),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a single-column action flow in portrait', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-portrait-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-wide-layout')), findsNothing);

    final greetingTop = tester.getTopLeft(find.byType(HomeGreetingHeader));
    final taskTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-task-panel')),
    );
    expect(greetingTop.dy, lessThan(taskTop.dy));
  });

  testWidgets('fits compact quick flows without Home scrolling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pump();

    final planned = find.byKey(const ValueKey('home-planned-workout-action'));
    final assessment = find.byKey(const ValueKey('home-assessment-action'));

    expect(tester.getSize(planned).height, lessThanOrEqualTo(68));
    expect(tester.getSize(assessment).height, lessThanOrEqualTo(68));

    final homeScrollView = find.byType(SingleChildScrollView);
    final scrollable = find.descendant(
      of: homeScrollView,
      matching: find.byType(Scrollable),
    );
    final scrollableState = tester.state<ScrollableState>(scrollable);

    expect(scrollableState.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers the focused action panel in landscape', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-wide-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-portrait-layout')), findsNothing);
    expect(find.byKey(const ValueKey('home-task-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps compact portrait usable with 200 percent text scaling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: const HomeScreen(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-portrait-layout')), findsOneWidget);

    final plannedTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-planned-workout-action')),
    );
    final assessmentTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-assessment-action')),
    );
    expect(plannedTop.dy, lessThan(assessmentTop.dy));
  });

  testWidgets('shows the three latest earned badges in the Home showcase', (
    WidgetTester tester,
  ) async {
    final navigatorObserver = RecordingNavigatorObserver();
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      navigatorObservers: [navigatorObserver],
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        homeAchievementShowcaseProvider.overrideWith(
          (ref) async => HomeAchievementShowcaseData(
            rewards: [
              _achievementReward('golden_week', DateTime.utc(2026, 8, 7, 12)),
              _achievementReward(
                'controlled_tempo',
                DateTime.utc(2026, 8, 6, 12),
              ),
              _achievementReward(
                'exercise_explorer_3',
                DateTime.utc(2026, 8, 5, 12),
              ),
              _achievementReward(
                'first_reliable_analysis',
                DateTime.utc(2026, 8, 4, 12),
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final showcase = find.byKey(const ValueKey('home-achievement-showcase'));
    expect(showcase, findsOneWidget);
    expect(find.text('Başarım Vitrini'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-achievement-badge-golden_week')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-achievement-badge-controlled_tempo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-achievement-badge-exercise_explorer_3')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('home-achievement-badge-first_reliable_analysis'),
      ),
      findsNothing,
    );
    expect(find.text('Altın Hafta'), findsNothing);
    expect(find.text('Kontrollü Ritim'), findsNothing);
    expect(find.text('Hareket Kaşifi'), findsNothing);

    await tester.ensureVisible(showcase);
    await tester.pump();
    final pushesBeforeTap = navigatorObserver.pushCount;
    await tester.tap(showcase);
    await tester.pump();

    expect(navigatorObserver.pushCount, pushesBeforeTap + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the badge showcase usable at 200 percent text scaling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: const HomeScreen(),
      ),
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
        homeAchievementShowcaseProvider.overrideWith(
          (ref) async => HomeAchievementShowcaseData(
            rewards: [
              _achievementReward(
                'planned_workout_completed',
                DateTime.utc(2026, 8, 7, 12),
              ),
              _achievementReward(
                'exercise_explorer_3',
                DateTime.utc(2026, 8, 6, 12),
              ),
              _achievementReward(
                'first_reliable_analysis',
                DateTime.utc(2026, 8, 5, 12),
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final showcase = find.byKey(const ValueKey('home-achievement-showcase'));
    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(showcase, 220, scrollable: scrollable);
    await tester.pumpAndSettle();

    expect(showcase, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('home-achievement-badge-planned_workout_completed'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('translates the focused Home surface to English', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      home: const HomeScreen(),
      overrides: [
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.pushUp),
      ],
    );
    await tester.pump();

    expect(find.text('Workout Analysis'), findsOneWidget);
    expect(find.text('Start Analysis'), findsOneWidget);
    expect(find.text('Selected exercise: Push-up'), findsOneWidget);
    expect(find.text('Planned Workout'), findsOneWidget);
    expect(find.text('Camera Measurement'), findsOneWidget);
    expect(find.text('Active Goal'), findsNothing);
    expect(find.text('New achievement'), findsNothing);
    expect(find.text('View Achievements'), findsNothing);
    expect(find.text('Latest Session'), findsNothing);
  });
}

AchievementReward _achievementReward(String id, DateTime unlockedAt) {
  return AchievementReward(
    ownerId: 'owner',
    achievementId: id,
    definitionVersion: 1,
    unlockedAt: unlockedAt,
    qualifyingEventId: 'event-$id',
    isBackfilled: false,
    createdAt: unlockedAt,
    updatedAt: unlockedAt,
  );
}

HomeDashboardData _mixedDashboardData() {
  return const HomeDashboardData(
    totalAnalyses: 8,
    averageScore: 87,
    thisWeekCount: 3,
    bestScore: 93,
    scoreTrend: [
      ScoreTrendPoint(label: 'Pzt', score: 80),
      ScoreTrendPoint(label: 'Sal', score: 85),
      ScoreTrendPoint(label: 'Çar', score: 90),
    ],
    exerciseDistribution: [
      ExerciseDistributionItem(label: 'Plank', value: 25),
      ExerciseDistributionItem(label: 'Squat', value: 40),
      ExerciseDistributionItem(label: 'Push-up', value: 35),
    ],
    source: HomeDashboardSource.real,
  );
}

WorkoutSession _latestRangeSession() {
  return WorkoutSession(
    id: 'latest-session',
    ownerId: 'owner',
    exerciseType: 'squat',
    startedAt: DateTime(2026, 8, 3, 10, 30),
    endedAt: DateTime(2026, 8, 3, 10, 31),
    durationSec: 60,
    totalReps: 12,
    averageScore: 88,
    bestScore: 94,
    validReps: 10,
    lowConfidenceReps: 1,
    invalidReps: 1,
    formWarningCount: 1,
  );
}
