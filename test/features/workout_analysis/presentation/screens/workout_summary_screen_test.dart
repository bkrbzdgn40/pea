import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_live_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_metrics_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/completed_session_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_detail_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_history_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/workout_summary_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

Finder _summaryMetricText(String text) {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('workout-summary-metrics')),
    matching: find.text(text),
  );
}

Finder _summaryVolumeText(String text) {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('workout-summary-volume')),
    matching: find.text(text),
  );
}

Future<void> _expandSummaryDetails(WidgetTester tester) async {
  final details = find.byKey(
    const ValueKey<String>('workout-summary-secondary-details'),
  );
  await tester.ensureVisible(details);
  await tester.pump();
  await tester.tap(details);
  await tester.pumpAndSettle();
}

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
    expect(
      find.byKey(const ValueKey('workout-summary-outcome-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workout-summary-strength')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('workout-summary-focus')), findsOneWidget);
    expect(_summaryVolumeText('Toplam tekrar'), findsOneWidget);
    expect(_summaryVolumeText('12'), findsOneWidget);
    expect(_summaryVolumeText('1:05'), findsOneWidget);
    expect(find.text('Ortalama form ve hareket aralığı skoru'), findsOneWidget);
    expect(
      _summaryMetricText('En iyi form ve hareket aralığı skoru'),
      findsNothing,
    );
    expect(find.text('Geçmişe Dön'), findsOneWidget);
    expect(find.text('Detayı Gör'), findsOneWidget);

    final primaryValue = tester.widget<Text>(
      find.byKey(const ValueKey<String>('workout-summary-primary-value')),
    );
    expect(primaryValue.data, '90');
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
      expect(_summaryVolumeText('Toplam tekrar'), findsOneWidget);
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
          validationReasons: <String>['coverage loss'],
          score: 90,
        ),
        WorkoutRep(
          repIndex: 2,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'lowConfidence',
          validationReasons: <String>['insufficient rom'],
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

    expect(_summaryVolumeText('Toplam tekrar'), findsOneWidget);
    expect(find.text('Geçerli: 2'), findsNothing);
    expect(find.text('Düşük Güven: 1'), findsNothing);
    expect(find.text('Geçersiz: 1'), findsNothing);
    expect(find.text('Görünürlük kaybı'), findsNothing);
    expect(find.text('Yetersiz hareket açıklığı'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('workout-summary-focus-message')),
      findsOneWidget,
    );
    expect(find.textContaining('Kamera açısını sabitle'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(find.text('Geçerli: 2'), findsOneWidget);
    expect(find.text('Düşük Güven: 1'), findsOneWidget);
    expect(find.text('Geçersiz: 1'), findsOneWidget);
    expect(find.text('Görünürlük kaybı'), findsOneWidget);
    expect(find.text('Yetersiz hareket açıklığı'), findsOneWidget);
  });

  testWidgets('averages only known measurement confidence values', (
    WidgetTester tester,
  ) async {
    final startedAt = DateTime(2024, 1, 5, 9, 30);
    final session = WorkoutSession(
      id: 'summary-confidence',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(seconds: 30)),
      durationSec: 30,
      totalReps: 3,
      averageScore: 90,
      bestScore: 94,
      worstScore: 86,
      validReps: 3,
      formWarningCount: 0,
      reps: const <WorkoutRep>[
        WorkoutRep(
          repIndex: 1,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          confidence: 0.9,
        ),
        WorkoutRep(
          repIndex: 2,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          confidence: 0.7,
        ),
        WorkoutRep(
          repIndex: 3,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
        ),
      ],
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(_summaryMetricText('Ortalama ölçüm güveni'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(_summaryMetricText('Ortalama ölçüm güveni'), findsOneWidget);
    expect(_summaryMetricText('%80'), findsOneWidget);
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

    expect(_summaryMetricText('Ortalama ROM'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(_summaryMetricText('Ortalama ROM'), findsOneWidget);
    expect(_summaryMetricText('Ortalama tempo'), findsOneWidget);
    expect(_summaryMetricText('Tempo tutarlılığı'), findsOneWidget);
    expect(_summaryMetricText('En hızlı tekrar'), findsOneWidget);
    expect(_summaryMetricText('En yavaş tekrar'), findsOneWidget);
    expect(_summaryMetricText('1.4 sn'), findsOneWidget);
    expect(_summaryMetricText('1.2 sn'), findsOneWidget);
    expect(_summaryMetricText('1.6 sn'), findsOneWidget);
    expect(_summaryMetricText('Sol tekrar'), findsOneWidget);
    expect(_summaryMetricText('Sağ tekrar'), findsOneWidget);
    expect(_summaryMetricText('Asimetri skoru'), findsOneWidget);
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

      expect(_summaryMetricText('Ortalama ROM'), findsNothing);

      await _expandSummaryDetails(tester);

      expect(_summaryMetricText('Ortalama ROM'), findsOneWidget);
      expect(_summaryMetricText('70.0°'), findsOneWidget);
      expect(find.text('1.3 sn'), findsNothing);
      expect(find.text('Ortalama tempo'), findsNothing);
      expect(find.text('Tempo tutarlılığı'), findsNothing);
    },
  );

  testWidgets('keeps the decision summary responsive in landscape', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = buildWorkoutSession(
      id: 'summary-landscape',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 10,
      averageScore: 84,
      bestScore: 92,
      durationSec: 60,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('workout-summary-wide-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps portrait summary usable at 200 percent text scale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = buildWorkoutSession(
      id: 'summary-large-text',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'standing_hip_abduction',
      totalReps: 8,
      averageScore: 78,
      bestScore: 86,
      durationSec: 70,
    );

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
        child: const WorkoutSummaryScreen(),
      ),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('workout-summary-portrait-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
    await _expandSummaryDetails(tester);
    final retryAction = find.byKey(
      const ValueKey<String>('workout-summary-retry-action'),
    );
    await tester.ensureVisible(retryAction);
    await tester.pump();
    await tester.tap(retryAction);
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

    final detailsButton = find.widgetWithText(OutlinedButton, 'Detayı Gör');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
  });

  testWidgets('history action opens the saved session list', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-history',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      exerciseType: 'squat',
      totalReps: 8,
      averageScore: 88,
      bestScore: 94,
      durationSec: 50,
    );
    final repository = TestSessionRepository(
      sessions: <WorkoutSession>[session],
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [
        completedSessionProvider.overrideWith((ref) => session),
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pump();

    final historyAction = find.byKey(
      const ValueKey<String>('workout-summary-history-action'),
    );
    await tester.ensureVisible(historyAction);
    await tester.tap(historyAction);
    await tester.pumpAndSettle();

    expect(find.byType(SessionHistoryScreen), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('uses hold result and volume without rep language', (
    WidgetTester tester,
  ) async {
    final startedAt = DateTime(2024, 1, 5, 9, 30);
    final session = WorkoutSession(
      id: 'summary-hold',
      ownerId: 'owner-1',
      exerciseType: 'plank',
      analysisKind: 'hold',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 5)),
      durationSec: 300,
      totalReps: 0,
      averageScore: 0,
      bestScore: 0,
      worstScore: 0,
      validReps: 0,
      invalidReps: 0,
      formWarningCount: 0,
      totalHoldSeconds: 42,
      bestHoldSeconds: 18,
      formBreakCount: 2,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    final primaryValue = tester.widget<Text>(
      find.byKey(const ValueKey<String>('workout-summary-primary-value')),
    );
    expect(primaryValue.data, '0:18');
    expect(find.text('En iyi tutuş'), findsOneWidget);
    expect(_summaryVolumeText('Toplam tutuş'), findsOneWidget);
    expect(_summaryVolumeText('0:42'), findsOneWidget);
    expect(_summaryVolumeText('5:00'), findsOneWidget);
    expect(find.text('Toplam tekrar'), findsNothing);
    expect(
      find.textContaining('vücut çizgisini daha sabit tut'),
      findsOneWidget,
    );
    expect(find.textContaining('Kısa ama temiz tekrarlarla'), findsNothing);
    expect(_summaryMetricText('Form kesintisi'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(_summaryMetricText('Form kesintisi'), findsOneWidget);
    expect(_summaryMetricText('2'), findsOneWidget);
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
    await _expandSummaryDetails(tester);

    await tester.ensureVisible(find.text('Ana Sayfaya Dön'));
    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Antrenman Analizi'), findsOneWidget);
  });
  testWidgets('keeps validation outcomes in the collapsed rep breakdown', (
    WidgetTester tester,
  ) async {
    final startedAt = DateTime(2024, 1, 9, 9);
    final session = WorkoutSession(
      id: 'summary-outcomes',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(seconds: 40)),
      durationSec: 40,
      totalReps: 3,
      averageScore: 82,
      bestScore: 90,
      worstScore: 74,
      validReps: 2,
      lowConfidenceReps: 1,
      invalidReps: 1,
      formWarningCount: 1,
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
          score: 82,
        ),
        WorkoutRep(
          repIndex: 3,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'invalid',
        ),
        WorkoutRep(
          repIndex: 4,
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          validationStatus: 'valid',
          score: 74,
        ),
      ],
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    final hero = find.byKey(
      const ValueKey<String>('workout-summary-outcome-card'),
    );
    expect(
      find.descendant(of: hero, matching: find.text('Geçerli: 2')),
      findsNothing,
    );
    expect(find.text('Geçerli: 2'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(find.text('Geçerli: 2'), findsOneWidget);
    expect(find.text('Düşük Güven: 1'), findsOneWidget);
    expect(find.text('Geçersiz: 1'), findsOneWidget);
  });
  testWidgets('shows a concise warning only for limited measurement evidence', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'summary-limited-evidence',
      startedAt: DateTime(2024, 1, 5, 9, 30),
      totalReps: 8,
      averageScore: 96,
      preparationOutcome: PreparationOutcome.passed,
      measurementQuality: SessionMeasurementQuality.limited,
      averageMeasurementConfidence: 0.72,
      measurementSampleCount: 8,
    );

    await pumpTestApp(
      tester,
      home: const WorkoutSummaryScreen(),
      overrides: [completedSessionProvider.overrideWith((ref) => session)],
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('workout-summary-measurement-warning')),
      findsOneWidget,
    );
    expect(find.text('Ölçüm güvenilirliği sınırlı'), findsOneWidget);
    expect(
      find.textContaining('hedef ve başarım hesaplarına dahil edilmez'),
      findsOneWidget,
    );
    expect(_summaryMetricText('Ölçüm kalitesi'), findsNothing);

    await _expandSummaryDetails(tester);

    expect(_summaryMetricText('Ölçüm kalitesi'), findsOneWidget);
    expect(_summaryMetricText('Sınırlı'), findsOneWidget);
    expect(_summaryMetricText('8 ölçüm örneği'), findsOneWidget);
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
