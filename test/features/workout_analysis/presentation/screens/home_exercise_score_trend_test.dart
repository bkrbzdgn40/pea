import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/analytics_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/score_trend_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets('Analytics trend uses the selected exercise context', (
    tester,
  ) async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'squat-1',
          startedAt: DateTime(2024, 1, 1, 9),
          exerciseType: 'squat',
          averageScore: 70,
        ),
        buildWorkoutSession(
          id: 'push-1',
          startedAt: DateTime(2024, 1, 2, 9),
          exerciseType: 'push_up',
          averageScore: 99,
        ),
        buildWorkoutSession(
          id: 'squat-2',
          startedAt: DateTime(2024, 1, 3, 9),
          exerciseType: 'squat',
          averageScore: 80,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );

    await pumpTestApp(
      tester,
      home: const AnalyticsScreen(),
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        selectedExerciseProvider.overrideWith((ref) => ExerciseType.squat),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Squat Form Skoru Trendi'), findsOneWidget);
    expect(find.byKey(const Key('score-trend-card')), findsOneWidget);
    expect(find.byKey(const Key('score-trend-chart-surface')), findsOneWidget);
    expect(find.byKey(const Key('score-trend-latest-score')), findsOneWidget);
    expect(find.text('Push-up Form Skoru Trendi'), findsNothing);
    final spots = _trendSpots(tester);
    expect(spots, hasLength(2));
    expect(spots.last.x - spots.first.x, closeTo(2, 1e-9));

    await tester.scrollUntilVisible(find.text('Detayı Gör'), 250);
    await tester.tap(find.text('Detayı Gör'));
    await tester.pumpAndSettle();

    expect(find.byType(ScoreTrendDetailScreen), findsOneWidget);
    expect(find.text('Squat Form Skoru Trendi'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'Analytics does not show a form-score trend for hold-only history',
    (tester) async {
      final snapshot = UserSessionsSnapshot(
        sessions: [
          buildWorkoutSession(
            id: 'plank-hold',
            startedAt: DateTime(2024, 1, 1, 9),
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
        home: const AnalyticsScreen(),
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
          selectedExerciseProvider.overrideWith((ref) => ExerciseType.plank),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Form Skoru Trendi'), findsNothing);
    },
  );
}

List<FlSpot> _trendSpots(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.lineBarsData.single.spots;
}
