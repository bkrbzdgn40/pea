import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_statistics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_score_trend_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'trend provider keeps score samples within one exercise context',
    () async {
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
            averageScore: 95,
          ),
          buildWorkoutSession(
            id: 'squat-2',
            startedAt: DateTime(2024, 1, 3, 9),
            exerciseType: 'squat',
            averageScore: 80,
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
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
      );
      addTearDown(container.dispose);

      final squat = await container.read(
        exerciseScoreTrendProvider(ExerciseType.squat).future,
      );
      final pushUp = await container.read(
        exerciseScoreTrendProvider(ExerciseType.pushUp).future,
      );
      final plank = await container.read(
        exerciseScoreTrendProvider(ExerciseType.plank).future,
      );

      expect(squat.exercise, ExerciseType.squat);
      expect(
        squat.samples.map((sample) => sample.score).toList(growable: false),
        <double>[70, 80],
      );
      expect(
        pushUp.samples.map((sample) => sample.score).toList(growable: false),
        <double>[95],
      );
      expect(plank.samples, isEmpty);
      expect(plank.hasRealData, isFalse);
    },
  );

  test(
    'non-real snapshots never expose demo score samples as user truth',
    () async {
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => const UserSessionsSnapshot(
              sessions: [],
              source: UserSessionsSnapshotSource.error,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final trend = await container.read(
        exerciseScoreTrendProvider(ExerciseType.squat).future,
      );

      expect(trend.samples, isEmpty);
      expect(trend.hasRealData, isFalse);
    },
  );

  test('trend ranges use inclusive local calendar-day windows', () async {
    final snapshot = UserSessionsSnapshot(
      sessions: [
        buildWorkoutSession(
          id: 'outside-month',
          startedAt: DateTime(2023, 12, 1, 9),
          exerciseType: 'squat',
          averageScore: 50,
        ),
        buildWorkoutSession(
          id: 'inside-month',
          startedAt: DateTime(2023, 12, 20, 9),
          exerciseType: 'squat',
          averageScore: 60,
        ),
        buildWorkoutSession(
          id: 'week-boundary',
          startedAt: DateTime(2024, 1, 4),
          exerciseType: 'squat',
          averageScore: 70,
        ),
        buildWorkoutSession(
          id: 'inside-week',
          startedAt: DateTime(2024, 1, 8, 9),
          exerciseType: 'squat',
          averageScore: 80,
        ),
        buildWorkoutSession(
          id: 'future',
          startedAt: DateTime(2024, 1, 11),
          exerciseType: 'squat',
          averageScore: 90,
        ),
      ],
      source: UserSessionsSnapshotSource.real,
    );
    final container = ProviderContainer(
      overrides: [
        userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
      ],
    );
    addTearDown(container.dispose);

    final trend = await container.read(
      exerciseScoreTrendProvider(ExerciseType.squat).future,
    );
    final now = DateTime(2024, 1, 10, 12);

    expect(
      trend
          .samplesForRange(ScoreTrendRange.sevenDays, now: now)
          .map((sample) => sample.score)
          .toList(growable: false),
      <double>[70, 80],
    );
    expect(
      trend
          .samplesForRange(ScoreTrendRange.thirtyDays, now: now)
          .map((sample) => sample.score)
          .toList(growable: false),
      <double>[60, 70, 80],
    );
    expect(
      trend
          .samplesForRange(ScoreTrendRange.all, now: now)
          .map((sample) => sample.score)
          .toList(growable: false),
      <double>[50, 60, 70, 80, 90],
    );
  });

  test('chart windows preserve real calendar gaps and same-day times', () {
    final trend = ExerciseScoreTrendData(
      exercise: ExerciseType.squat,
      samples: [
        WorkoutScoreSample(startedAt: DateTime(2024, 1, 4, 9), score: 70),
        WorkoutScoreSample(startedAt: DateTime(2024, 1, 4, 18), score: 72),
        WorkoutScoreSample(startedAt: DateTime(2024, 1, 8, 9), score: 80),
      ],
      source: UserSessionsSnapshotSource.real,
    );
    final now = DateTime(2024, 1, 10, 12);
    final window = trend.chartWindowForRange(
      ScoreTrendRange.sevenDays,
      now: now,
    )!;

    expect(window.axisUnit, ScoreTrendAxisUnit.calendarDays);
    expect(window.startInclusive, DateTime(2024, 1, 4));
    expect(window.endExclusive, DateTime(2024, 1, 11));
    expect(window.positionFor(DateTime(2024, 1, 4, 9)), closeTo(0.375, 1e-9));
    expect(window.positionFor(DateTime(2024, 1, 4, 18)), closeTo(0.75, 1e-9));
    expect(window.positionFor(DateTime(2024, 1, 8, 9)), closeTo(4.375, 1e-9));
  });

  test('all-time chart uses calendar months and keeps full tooltip dates', () {
    final samples = [
      WorkoutScoreSample(startedAt: DateTime(2023, 12, 20, 9), score: 60),
      WorkoutScoreSample(startedAt: DateTime(2024, 1, 8, 18, 5), score: 75),
    ];
    final trend = ExerciseScoreTrendData(
      exercise: ExerciseType.squat,
      samples: samples,
      source: UserSessionsSnapshotSource.real,
    );
    final points = trend.detailPoints();
    final window = trend.chartWindowForRange(
      ScoreTrendRange.all,
      now: DateTime(2024, 1, 10),
    )!;

    expect(window.axisUnit, ScoreTrendAxisUnit.calendarMonths);
    expect(window.startInclusive, DateTime(2023, 12));
    expect(window.endExclusive, DateTime(2024, 2));
    expect(window.positionFor(samples.first.startedAt), lessThan(1));
    expect(window.positionFor(samples.last.startedAt), greaterThan(1));
    expect(points.first.startedAt, samples.first.startedAt);
    expect(points.last.tooltipLabel, '08.01.2024 18:05');
  });

  test(
    'trend keeps limited evidence marked and excludes insufficient samples',
    () async {
      final snapshot = UserSessionsSnapshot(
        sessions: [
          buildWorkoutSession(
            id: 'trusted',
            startedAt: DateTime(2024, 1, 1, 9),
            exerciseType: 'squat',
            totalReps: 8,
            averageScore: 80,
            preparationOutcome: PreparationOutcome.passed,
            measurementQuality: SessionMeasurementQuality.high,
            averageMeasurementConfidence: 0.95,
            measurementSampleCount: 8,
          ),
          buildWorkoutSession(
            id: 'limited',
            startedAt: DateTime(2024, 1, 2, 9),
            exerciseType: 'squat',
            totalReps: 8,
            averageScore: 100,
            preparationOutcome: PreparationOutcome.passed,
            measurementQuality: SessionMeasurementQuality.limited,
            averageMeasurementConfidence: 0.7,
            measurementSampleCount: 8,
          ),
          buildWorkoutSession(
            id: 'insufficient',
            startedAt: DateTime(2024, 1, 3, 9),
            exerciseType: 'squat',
            totalReps: 1,
            averageScore: 99,
            preparationOutcome: PreparationOutcome.passed,
            measurementQuality: SessionMeasurementQuality.insufficient,
            averageMeasurementConfidence: 0.99,
            measurementSampleCount: 1,
          ),
        ],
        source: UserSessionsSnapshotSource.real,
      );
      final container = ProviderContainer(
        overrides: [
          userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
        ],
      );
      addTearDown(container.dispose);

      final trend = await container.read(
        exerciseScoreTrendProvider(ExerciseType.squat).future,
      );

      expect(
        trend.samples.map((sample) => sample.score).toList(growable: false),
        <double>[80, 100],
      );
      expect(trend.samples.first.contributesToScoreAggregates, isTrue);
      expect(trend.samples.last.contributesToScoreAggregates, isFalse);
      expect(trend.samples.last.hasEvidenceWarning, isTrue);
      expect(trend.averageScoreFor(trend.samples), 80);
      expect(trend.bestAverageScoreFor(trend.samples), 80);
    },
  );
}
