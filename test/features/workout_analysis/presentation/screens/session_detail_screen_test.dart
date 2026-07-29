import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'renders formatted session detail content and loaded rep details',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-1',
        ownerId: 'owner-1',
        exerciseType: 'push_up',
        startedAt: DateTime(2024, 1, 5, 9, 30),
        totalReps: 1,
        averageScore: 89.6,
        bestScore: 93,
        durationSec: 65,
      );
      final repository = TestSessionRepository(
        sessionById: {'session-1': session},
        repsBySessionId: {
          'session-1': const [
            WorkoutRep(
              repIndex: 1,
              exerciseType: 'push_up',
              analysisKind: 'rangeRep',
              validationStatus: 'valid',
              validationReasons: <String>['insufficient rom'],
              score: 89.6,
              minPrimaryMetric: 74.3,
              worstFormMetric: 81.2,
              descentMillis: 450,
              ascentMillis: 550,
              feedback: 'Daha kontrollu cikis',
              selectedSideLabel: 'left',
            ),
          ],
        },
      );

      await pumpTestApp(
        tester,
        home: SessionDetailScreen(session: session),
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Şınav'), findsOneWidget);
      expect(find.text('05.01.2024 09:30'), findsOneWidget);
      expect(find.textContaining('1:05'), findsWidgets);
      expect(find.text('89.6'), findsNWidgets(4));
      expect(find.text('Tekrar Detayları'), findsOneWidget);
      expect(find.text('Deneme 1'), findsOneWidget);
      expect(find.text('Geçerli'), findsWidgets);
      expect(find.text('450 ms / 550 ms'), findsOneWidget);
      expect(find.text('Sol'), findsOneWidget);
    },
  );

  testWidgets(
    'formats biceps curl session detail titles through the canonical exercise string',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-biceps',
        ownerId: 'owner-1',
        exerciseType: 'biceps_curl',
        startedAt: DateTime(2024, 1, 6, 10, 15),
        totalReps: 1,
        averageScore: 91.2,
        bestScore: 96,
        durationSec: 75,
      );

      await pumpTestApp(
        tester,
        home: SessionDetailScreen(session: session),
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            TestSessionRepository(sessionById: {'session-biceps': session}),
          ),
        ],
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Biseps Curl'), findsOneWidget);
      expect(find.text('06.01.2024 10:15'), findsOneWidget);
    },
  );

  testWidgets('localizes stored feedback and report copy in English', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-en',
      ownerId: 'owner-1',
      exerciseType: 'push_up',
      startedAt: DateTime(2024, 1, 7, 11),
      totalReps: 1,
      averageScore: 90,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-en': session},
      repsBySessionId: {
        'session-en': const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'push_up',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            validationReasons: <String>[],
            score: 90,
            feedback: 'Başarılı!',
          ),
        ],
      },
    );

    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.textContaining('Feedback: Rep completed!'), findsOneWidget);
    expect(find.textContaining('1 reps counted: 1 were valid'), findsOneWidget);
  });

  testWidgets('deletes a session only after explicit confirmation', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-delete',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessions: [session],
      sessionById: {'session-delete': session},
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey<String>('session-delete-button'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Oturum silinsin mi?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedSessionIds, ['session-delete']);
  });

  testWidgets('cancel keeps the saved session', (WidgetTester tester) async {
    final session = buildWorkoutSession(
      id: 'session-cancel',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-cancel': session},
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey<String>('session-delete-button'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-cancel')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedSessionIds, isEmpty);
  });

  testWidgets('shows an actionable error when deletion fails', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-failure',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-failure': session},
      deleteSessionError: StateError('offline'),
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey<String>('session-delete-button'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Oturum silinemedi. Bağlantını kontrol edip tekrar dene.'),
      findsOneWidget,
    );
    expect(repository.deletedSessionIds, isEmpty);
  });
}
