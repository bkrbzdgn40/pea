import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_detail_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_history_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'renders formatted session history cards and keeps tap navigation',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-1',
        ownerId: 'owner-1',
        exerciseType: 'push_up',
        startedAt: DateTime(2024, 1, 5, 9, 30),
        totalReps: 12,
        averageScore: 89.6,
        bestScore: 94,
        durationSec: 65,
      );
      final repository = TestSessionRepository(
        sessions: [session],
        sessionById: {'session-1': session},
        repsBySessionId: {
          'session-1': const [
            WorkoutRep(
              repIndex: 1,
              exerciseType: 'push_up',
              analysisKind: 'rangeRep',
              validationStatus: 'valid',
              validationReasons: <String>['coverage loss'],
              score: 92,
              descentMillis: 400,
              ascentMillis: 500,
            ),
          ],
        },
      );
      final observer = RecordingNavigatorObserver();

      await pumpTestApp(
        tester,
        home: const SessionHistoryScreen(),
        navigatorObservers: [observer],
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const TestAuthRepository(currentUserId: 'owner-1'),
          ),
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Şınav'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('05.01.2024 09:30'), findsOneWidget);
      expect(find.text('Ort. Form/ROM'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('Geçerli: 12'), findsOneWidget);

      final pushCountBeforeTap = observer.pushCount;

      await tester.tap(find.text('Şınav'));
      await tester.pumpAndSettle();

      expect(observer.pushCount, pushCountBeforeTap + 1);
      expect(find.byType(SessionDetailScreen), findsOneWidget);
    },
  );

  testWidgets('renders the empty-state presentation when no sessions exist', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const SessionHistoryScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessions: const []),
        ),
      ],
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Henüz oturum yok'), findsOneWidget);
    expect(
      find.text('Kaydedilmiş antrenmanların burada görünecek.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'formats biceps curl history titles through the canonical title path',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-biceps',
        ownerId: 'owner-1',
        exerciseType: 'biceps_curl',
        startedAt: DateTime(2024, 1, 6, 10, 15),
        totalReps: 8,
        averageScore: 91.2,
        bestScore: 96,
        durationSec: 75,
      );

      await pumpTestApp(
        tester,
        home: const SessionHistoryScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const TestAuthRepository(currentUserId: 'owner-1'),
          ),
          sessionRepositoryProvider.overrideWithValue(
            TestSessionRepository(
              sessions: [session],
              sessionById: {'session-biceps': session},
            ),
          ),
        ],
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Biseps Curl'), findsOneWidget);
    },
  );

  testWidgets('filters history by exercise without mixing other sessions', (
    WidgetTester tester,
  ) async {
    final squat = buildWorkoutSession(
      id: 'session-squat',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 6, 10),
      totalReps: 10,
      averageScore: 85,
      durationSec: 60,
    );
    final pushUp = buildWorkoutSession(
      id: 'session-push-up',
      ownerId: 'owner-1',
      exerciseType: 'push_up',
      startedAt: DateTime(2024, 1, 5, 10),
      totalReps: 8,
      averageScore: 82,
      durationSec: 55,
    );

    await pumpTestApp(
      tester,
      home: const SessionHistoryScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessions: [squat, pushUp]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('session-history-card-session-squat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('session-history-card-session-push-up')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('session-history-exercise-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('session-history-card-session-squat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('session-history-card-session-push-up')),
      findsNothing,
    );
    expect(find.text('1 oturum gösteriliyor'), findsOneWidget);
  });

  testWidgets('uses a landscape grid and shows score change', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final latest = buildWorkoutSession(
      id: 'session-latest',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 6, 10),
      totalReps: 10,
      averageScore: 88,
      durationSec: 60,
    );
    final previous = buildWorkoutSession(
      id: 'session-previous',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 5, 10),
      totalReps: 10,
      averageScore: 83,
      durationSec: 60,
    );

    await pumpTestApp(
      tester,
      home: const SessionHistoryScreen(),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessions: [latest, previous]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('session-history-grid')), findsOneWidget);
    expect(find.text('Önceki oturuma göre +5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a list at large text scale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = buildWorkoutSession(
      id: 'session-large-text',
      ownerId: 'owner-1',
      exerciseType: 'standing_hip_abduction',
      startedAt: DateTime(2024, 1, 6, 10),
      totalReps: 10,
      averageScore: 88,
      durationSec: 60,
    );

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          textScaler: TextScaler.linear(2),
        ),
        child: const SessionHistoryScreen(),
      ),
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const TestAuthRepository(currentUserId: 'owner-1'),
        ),
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessions: [session]),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('session-history-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks only sessions with limited measurement evidence', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final limited = buildWorkoutSession(
        id: 'session-limited',
        ownerId: 'owner-1',
        startedAt: DateTime(2024, 1, 6, 10),
        totalReps: 8,
        averageScore: 95,
        preparationOutcome: PreparationOutcome.passed,
        measurementQuality: SessionMeasurementQuality.limited,
        averageMeasurementConfidence: 0.7,
        measurementSampleCount: 8,
      );
      final trusted = buildWorkoutSession(
        id: 'session-trusted',
        ownerId: 'owner-1',
        startedAt: DateTime(2024, 1, 5, 10),
        totalReps: 8,
        averageScore: 85,
        preparationOutcome: PreparationOutcome.passed,
        measurementQuality: SessionMeasurementQuality.high,
        averageMeasurementConfidence: 0.95,
        measurementSampleCount: 8,
      );

      await pumpTestApp(
        tester,
        home: const SessionHistoryScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const TestAuthRepository(currentUserId: 'owner-1'),
          ),
          sessionRepositoryProvider.overrideWithValue(
            TestSessionRepository(sessions: [limited, trusted]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('session-history-measurement-warning'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Ölçüm güvenilirliği sınırlı'),
        findsOneWidget,
      );
      expect(find.text('Önceki oturuma göre +10'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
