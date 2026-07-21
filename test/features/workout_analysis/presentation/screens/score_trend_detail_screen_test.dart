import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/score_trend_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'detail screen shows only the explicit exercise form-score trend',
    (tester) async {
      final snapshot = UserSessionsSnapshot(
        sessions: [
          buildWorkoutSession(
            id: 'squat-1',
            startedAt: DateTime(2024, 1, 1, 9),
            exerciseType: 'squat',
            totalReps: 10,
            averageScore: 60,
            bestScore: 95,
          ),
          buildWorkoutSession(
            id: 'push-1',
            startedAt: DateTime(2024, 1, 2, 9),
            exerciseType: 'push_up',
            totalReps: 12,
            averageScore: 99,
            bestScore: 100,
          ),
          buildWorkoutSession(
            id: 'squat-2',
            startedAt: DateTime(2024, 1, 3, 9),
            exerciseType: 'squat',
            totalReps: 8,
            averageScore: 65,
            bestScore: 90,
          ),
          buildWorkoutSession(
            id: 'plank-hold',
            startedAt: DateTime(2024, 1, 4, 9),
            exerciseType: 'plank',
            analysisKind: 'hold',
            totalReps: 0,
            averageScore: 0,
            bestScore: 0,
          ),
        ],
        source: UserSessionsSnapshotSource.real,
      );

      await pumpTestApp(
        tester,
        home: const ScoreTrendDetailScreen(exercise: ExerciseType.squat),
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Squat Form Skoru Trendi'), findsAtLeastNWidgets(1));
      expect(find.text('01.01'), findsOneWidget);
      expect(find.text('03.01'), findsOneWidget);
      expect(find.text('02.01'), findsNothing);
      expect(find.text('04.01'), findsNothing);
      expect(find.text('Oturum'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Son Form Skoru'), findsOneWidget);
      expect(find.text('En İyi Form Skoru'), findsOneWidget);
      expect(find.text('65'), findsAtLeastNWidgets(1));
      expect(find.text('99'), findsNothing);
    },
  );

  testWidgets('hold-only exercise does not invent a zero score trend', (
    tester,
  ) async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'plank-hold',
          startedAt: DateTime(2024, 1, 4, 9),
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );

    await pumpTestApp(
      tester,
      home: const ScoreTrendDetailScreen(exercise: ExerciseType.plank),
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Plank için henüz form skoru trendi yok.'),
      findsOneWidget,
    );
    expect(find.text('0'), findsNothing);
  });
}
