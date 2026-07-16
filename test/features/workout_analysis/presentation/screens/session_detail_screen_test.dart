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

      expect(find.text('Push Up'), findsOneWidget);
      expect(find.text('05.01.2024 09:30'), findsOneWidget);
      expect(find.textContaining('1:05'), findsWidgets);
      expect(find.text('89.6'), findsNWidgets(4));
      expect(find.text('Tekrar Detayları'), findsOneWidget);
      expect(find.text('Tekrar 1'), findsOneWidget);
      expect(find.text('Geçerli'), findsWidgets);
      expect(find.text('450 ms / 550 ms'), findsOneWidget);
      expect(find.text('Sol'), findsOneWidget);
    },
  );
}
