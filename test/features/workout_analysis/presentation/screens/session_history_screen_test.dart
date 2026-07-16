import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
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

      expect(find.text('Push Up'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('05.01.2024 09:30'), findsOneWidget);
      expect(find.text('Ort. Skor'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);

      final pushCountBeforeTap = observer.pushCount;

      await tester.tap(find.text('Push Up'));
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

    expect(find.text('Henuz oturum yok'), findsOneWidget);
    expect(
      find.text('Kaydedilmis antrenmanlarin burada gorunecek.'),
      findsOneWidget,
    );
  });
}
