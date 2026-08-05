import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_score_trend_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/score_trend_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'detail trend filters the explicit exercise by 7 days, 30 days, and all time',
    (tester) async {
      final snapshot = UserSessionsSnapshot(
        sessions: [
          buildWorkoutSession(
            id: 'squat-all-time',
            startedAt: DateTime(2023, 12, 1, 9),
            exerciseType: 'squat',
            totalReps: 10,
            averageScore: 55,
            bestScore: 80,
          ),
          buildWorkoutSession(
            id: 'squat-month',
            startedAt: DateTime(2023, 12, 20, 9),
            exerciseType: 'squat',
            totalReps: 10,
            averageScore: 60,
            bestScore: 85,
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
            id: 'squat-week-boundary',
            startedAt: DateTime(2024, 1, 4),
            exerciseType: 'squat',
            totalReps: 8,
            averageScore: 65,
            bestScore: 90,
          ),
          buildWorkoutSession(
            id: 'plank-hold',
            startedAt: DateTime(2024, 1, 5, 9),
            exerciseType: 'plank',
            analysisKind: 'hold',
            totalReps: 0,
            averageScore: 0,
            bestScore: 0,
          ),
          buildWorkoutSession(
            id: 'squat-latest',
            startedAt: DateTime(2024, 1, 8, 9),
            exerciseType: 'squat',
            totalReps: 9,
            averageScore: 75,
            bestScore: 95,
          ),
        ],
        source: UserSessionsSnapshotSource.real,
      );

      await pumpTestApp(
        tester,
        home: const ScoreTrendDetailScreen(exercise: ExerciseType.squat),
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
          scoreTrendClockProvider.overrideWithValue(
            () => DateTime(2024, 1, 10, 12),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Squat Form Skoru Trendi'), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const Key('score-trend-range-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('score-trend-range-thirty-days')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('score-trend-detail-hero')), findsOneWidget);
      expect(
        find.byKey(const Key('score-trend-chart-surface')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('score-trend-summary-grid')), findsOneWidget);
      expect(find.text('12.12'), findsOneWidget);
      expect(find.text('09.01'), findsOneWidget);
      final thirtyDaySpots = _trendSpots(tester);
      expect(thirtyDaySpots, hasLength(3));
      expect(
        thirtyDaySpots.map((spot) => spot.y),
        orderedEquals(<double>[60, 65, 75]),
      );
      expect(thirtyDaySpots[0].x, closeTo(8.375, 1e-9));
      expect(thirtyDaySpots[1].x, closeTo(23, 1e-9));
      expect(thirtyDaySpots[2].x, closeTo(27.375, 1e-9));
      expect(
        find.descendant(
          of: find.byKey(const Key('score-trend-session-count')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.text('99'), findsNothing);

      await tester.tap(find.byKey(const Key('score-trend-range-seven-days')));
      await tester.pumpAndSettle();

      expect(find.text('04.01'), findsOneWidget);
      expect(find.text('08.01'), findsOneWidget);
      final sevenDaySpots = _trendSpots(tester);
      expect(sevenDaySpots, hasLength(2));
      expect(sevenDaySpots[0].x, closeTo(0, 1e-9));
      expect(sevenDaySpots[1].x, closeTo(4.375, 1e-9));
      expect(
        find.descendant(
          of: find.byKey(const Key('score-trend-session-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('score-trend-range-all')));
      await tester.pumpAndSettle();

      expect(find.text('12.23'), findsOneWidget);
      expect(find.text('01.24'), findsOneWidget);
      final allTimeSpots = _trendSpots(tester);
      expect(allTimeSpots, hasLength(4));
      expect(
        allTimeSpots[1].x - allTimeSpots[0].x,
        greaterThan(allTimeSpots[3].x - allTimeSpots[2].x),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('score-trend-session-count')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('range with no samples keeps the selector and shows guidance', (
    tester,
  ) async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'old-squat',
          startedAt: DateTime(2023, 1, 4, 9),
          exerciseType: 'squat',
          averageScore: 70,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );

    await pumpTestApp(
      tester,
      home: const ScoreTrendDetailScreen(exercise: ExerciseType.squat),
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        scoreTrendClockProvider.overrideWithValue(
          () => DateTime(2024, 1, 10, 12),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score-trend-range-selector')), findsOneWidget);
    expect(
      find.text('Squat için son 30 gün içinde form skoru yok.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('score-trend-detail-hero')), findsNothing);

    await tester.tap(find.byKey(const Key('score-trend-range-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score-trend-detail-hero')), findsOneWidget);
    expect(find.text('01.23'), findsOneWidget);
    expect(_trendSpots(tester).single.x, closeTo(3.375 / 31, 1e-9));
  });

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

List<FlSpot> _trendSpots(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  return chart.data.lineBarsData.single.spots;
}
