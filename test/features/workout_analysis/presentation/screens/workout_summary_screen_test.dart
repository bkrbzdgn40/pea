import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_live_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_metrics_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_detail_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_summary_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets('renders summary values from the completed workout session', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-1',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'push_up',
      totalReps: 12,
      averageScore: 89.6,
      bestScore: 95,
      durationSec: 65,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(find.text('Şınav özeti'), findsOneWidget);
    expect(find.text('Toplam tekrar'), findsOneWidget);
    expect(find.text('Ortalama form ve hareket aralığı skoru'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('1:05'), 200);

    expect(find.text('90'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets(
    'renders the missing-session empty state when session is absent',
    (WidgetTester tester) async {
      await pumpTestApp(
        tester,
        home: const WorkoutSummaryScreen(),
        overrides: [completedSessionProvider.overrideWith((ref) => null)],
      );
      await tester.pump();

      expect(find.text('Oturum verisi bulunamadı.'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    },
  );

  testWidgets(
    'formats biceps curl summary titles through the existing summary path',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'summary-biceps',
        startedAt: DateTime(2024, 1, 6, 10, 15),
        exerciseType: 'biceps_curl',
        totalReps: 8,
        averageScore: 91.2,
        bestScore: 96,
        durationSec: 75,
      );

      await pumpTestApp(
        tester,
        home: const WorkoutSummaryScreen(),
        overrides: [completedSessionProvider.overrideWith((ref) => session)],
      );
      await tester.pump();

      expect(find.text('Biseps Curl özeti'), findsOneWidget);
      expect(find.text('Toplam tekrar'), findsOneWidget);
    },
  );

  testWidgets('separates counted low-confidence reps from rejected attempts', (
    WidgetTester tester,
  ) async {
    final startedAt = DateTime(2024, 1, 5, 9, 30);
    final session = WorkoutSession(
      id: 'summary-validation-semantics',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(seconds: 30)),
      durationSec: 30,
      totalReps: 3,
      averageScore: 80,
      bestScore: 90,
      worstScore: 70,
      validReps: 2,
      lowConfidenceReps: 1,
      invalidReps: 1,
      formWarningCount: 0,
      reps: const <WorkoutRep>[
        WorkoutRep(
          repIndex: 1,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'valid',
          score: 90,
        ),
        WorkoutRep(
          repIndex: 2,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'lowConfidence',
          score: 80,
        ),
        WorkoutRep(
          repIndex: 3,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'valid',
          score: 70,
        ),
        WorkoutRep(
          repIndex: 4,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'invalid',
        ),
      ],
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Düşük Güven'), 200);

    expect(find.text('Toplam tekrar'), findsOneWidget);
    expect(find.text('Düşük Güven'), findsOneWidget);
    expect(find.text('Geçersiz deneme'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('renders rich live metrics captured at session completion', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-rich',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'lunge',
      totalReps: 6,
      averageScore: 88,
      bestScore: 94,
      durationSec: 80,
    );
    final frameBuilder = ExerciseMetricSnapshotBuilder(
      scope: ExerciseMetricScope.frame,
    );
    final sessionBuilder =
        ExerciseMetricSnapshotBuilder(scope: ExerciseMetricScope.session)
          ..set(ExerciseMetricRegistry.repetitionCount, 6)
          ..set(ExerciseMetricRegistry.rangeOfMotion, 48.5)
          ..set(
            ExerciseMetricRegistry.tempo,
            const Duration(milliseconds: 1400),
          )
          ..set(ExerciseMetricRegistry.symmetry, 6.5)
          ..set(ExerciseMetricRegistry.asymmetryScore, 12.0);
    final metrics = WorkoutLiveMetricsSnapshot(
      frameMetrics: frameBuilder.build(),
      sessionMetrics: sessionBuilder.build(),
      leftRepCount: 3,
      rightRepCount: 3,
      tempoConsistencyScore: 91,
      fastestRepDuration: const Duration(milliseconds: 1200),
      slowestRepDuration: const Duration(milliseconds: 1600),
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [
        completedSessionProvider.overrideWith((ref) => session),
        completedSessionMetricsProvider.overrideWith((ref) => metrics),
      ],
    );
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Asimetri skoru'), 200);

    expect(find.text('Ortalama ROM'), findsOneWidget);
    expect(find.text('Ortalama tempo'), findsNothing);
    expect(find.text('Tempo tutarlılığı'), findsNothing);
    expect(find.text('En hızlı tekrar'), findsNothing);
    expect(find.text('En yavaş tekrar'), findsNothing);
    expect(find.text('Sol tekrar'), findsOneWidget);
    expect(find.text('Sağ tekrar'), findsOneWidget);
    expect(find.text('Asimetri skoru'), findsOneWidget);
  });

  testWidgets(
    'falls back to persisted rep metrics when live snapshot is partial',
    (WidgetTester tester) async {
      final startedAt = DateTime(2024, 1, 5, 9, 30);
      final session = WorkoutSession(
        id: 'summary-partial-live',
        ownerId: 'owner-1',
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(seconds: 30)),
        durationSec: 30,
        totalReps: 2,
        averageScore: 90,
        bestScore: 94,
        worstScore: 86,
        validReps: 2,
        invalidReps: 0,
        formWarningCount: 0,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            primaryRom: 60,
            descentMillis: 500,
            ascentMillis: 700,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            primaryRom: 80,
            descentMillis: 600,
            ascentMillis: 800,
          ),
        ],
      );
      final liveMetrics = WorkoutLiveMetricsSnapshot(
        frameMetrics: ExerciseMetricSnapshotBuilder(
          scope: ExerciseMetricScope.frame,
        ).build(),
        sessionMetrics: (ExerciseMetricSnapshotBuilder(
          scope: ExerciseMetricScope.session,
        )..set(ExerciseMetricRegistry.repetitionCount, 2)).build(),
        tempoConsistencyScore: 95,
      );

      await pumpTestApp(
        tester,
        home: const WorkoutSummaryScreen(),
        overrides: [
          completedSessionProvider.overrideWith((ref) => session),
          completedSessionMetricsProvider.overrideWith((ref) => liveMetrics),
        ],
      );
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Ortalama ROM'), 200);
      expect(find.text('70.0°'), findsOneWidget);
      expect(find.text('1.3 sn'), findsNothing);
      expect(find.text('Ortalama tempo'), findsNothing);
      expect(find.text('Tempo tutarlılığı'), findsNothing);
    },
  );

  testWidgets('repeat action returns true to the live analysis flow', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-repeat',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 8,
      averageScore: 88,
      bestScore: 94,
      durationSec: 50,
    );
    bool? retryResult;

    await pumpTestApp(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                retryResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const WorkoutSummaryScreen(),
                  ),
                );
              },
              child: const Text('Open summary'),
            ),
          ),
        ),
      ),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );

    await tester.tap(find.text('Open summary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aynı Hareketi Tekrarla'));
    await tester.pumpAndSettle();

    expect(retryResult, isTrue);
    expect(find.text('Open summary'), findsOneWidget);
  });

  testWidgets('details action opens the saved session report', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-details',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 8,
      averageScore: 88,
      bestScore: 94,
      durationSec: 50,
    );
    final repository = TestSessionRepository(
      sessions: <WorkoutSession>[session],
      sessionById: <String, WorkoutSession?>{session.id: session},
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [
        completedSessionProvider.overrideWith((ref) => session),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pump();

    final detailsButton = find.widgetWithText(TextButton, 'Detayı Gör');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
  });

  testWidgets('keeps the explicit home navigation behavior', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-1',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 12,
      averageScore: 89.6,
      bestScore: 95,
      durationSec: 65,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [
        completedSessionProvider.overrideWith((ref) => session),
        homeDashboardProvider.overrideWith((ref) => _dashboardData()),
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.real,
            goals: <WorkoutGoal>[],
          ),
        ),
        achievementsProvider.overrideWith(
          (ref) => const AchievementsState(
            source: AchievementsDataSource.real,
            achievements: <Achievement>[],
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Antrenman Analizi'), findsOneWidget);
  });
}

HomeDashboardData _dashboardData() {
  return const HomeDashboardData(
    totalAnalyses: 4,
    averageScore: 86,
    thisWeekCount: 2,
    bestScore: 91,
    scoreTrend: [
      ScoreTrendPoint(label: 'Pzt', score: 82),
      ScoreTrendPoint(label: 'Sal', score: 86),
    ],
    exerciseDistribution: [
      ExerciseDistributionItem(label: 'Squat', value: 100),
    ],
    source: HomeDashboardSource.real,
  );
}
