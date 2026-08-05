import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_statistics_calculator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';

import '../../../support/workout_statistics_test_support.dart';

void main() {
  test(
    'mixed range-rep and hold sessions keep canonical score stats and samples',
    () {
      final calculator = WorkoutStatisticsCalculator(
        clock: () => DateTime(2024, 1, 10, 12),
      );
      final sessions = [
        buildWorkoutSession(
          id: 'range-2',
          startedAt: DateTime(2024, 1, 3, 9),
          totalReps: 12,
          averageScore: 100,
        ),
        buildWorkoutSession(
          id: 'hold-1',
          startedAt: DateTime(2024, 1, 2, 9),
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
        ),
        buildWorkoutSession(
          id: 'range-1',
          startedAt: DateTime(2024, 1, 1, 9),
          totalReps: 10,
          averageScore: 80,
        ),
      ];

      final statistics = calculator.calculate(sessions);

      expect(statistics.averageScore, closeTo(90, 0.001));
      expect(statistics.bestScore, 100);
      expect(statistics.bestAverageScore, 100);
      expect(
        statistics.chronologicalScoreSamples
            .map((sample) => sample.score)
            .toList(growable: false),
        <double>[80, 100],
      );
      expect(
        statistics.chronologicalScoreSamples
            .map((sample) => sample.startedAt)
            .toList(growable: false),
        <DateTime>[DateTime(2024, 1, 1, 9), DateTime(2024, 1, 3, 9)],
      );
    },
  );

  test(
    'bestAverageScore stays tied to eligible average-score samples not session bestScore',
    () {
      final calculator = WorkoutStatisticsCalculator(
        clock: () => DateTime(2024, 1, 10, 12),
      );
      final sessions = [
        buildWorkoutSession(
          id: 'range-1',
          startedAt: DateTime(2024, 1, 1, 9),
          totalReps: 10,
          averageScore: 60,
          bestScore: 95,
        ),
        buildWorkoutSession(
          id: 'range-2',
          startedAt: DateTime(2024, 1, 2, 9),
          totalReps: 12,
          averageScore: 70,
          bestScore: 100,
        ),
      ];

      final statistics = calculator.calculate(sessions);

      expect(statistics.bestScore, 100);
      expect(statistics.bestAverageScore, 70);
    },
  );

  test('hold-only snapshot returns zeroed score statistics', () {
    final calculator = WorkoutStatisticsCalculator(
      clock: () => DateTime(2024, 1, 10, 12),
    );
    final sessions = [
      buildWorkoutSession(
        id: 'hold-1',
        startedAt: DateTime(2024, 1, 1, 9),
        exerciseType: 'plank',
        analysisKind: 'hold',
        totalReps: 0,
        averageScore: 0,
        bestScore: 0,
      ),
    ];

    final statistics = calculator.calculate(sessions);

    expect(statistics.averageScore, 0);
    expect(statistics.bestScore, 0);
    expect(statistics.chronologicalScoreSamples, isEmpty);
  });

  test('latestScoreSamples returns the last seven canonical score samples', () {
    final calculator = WorkoutStatisticsCalculator(
      clock: () => DateTime(2024, 1, 10, 12),
    );
    final sessions = [
      for (var index = 0; index < 9; index++)
        buildWorkoutSession(
          id: 'range-$index',
          startedAt: DateTime(2024, 1, index + 1, 9),
          totalReps: 10,
          averageScore: (index + 1) * 10,
        ),
      buildWorkoutSession(
        id: 'hold-1',
        startedAt: DateTime(2024, 1, 5, 18),
        exerciseType: 'plank',
        analysisKind: 'hold',
        totalReps: 0,
        averageScore: 0,
        bestScore: 0,
      ),
    ];

    final statistics = calculator.calculate(sessions);

    expect(
      statistics
          .latestScoreSamples()
          .map((sample) => sample.score)
          .toList(growable: false),
      <double>[30, 40, 50, 60, 70, 80, 90],
    );
  });

  test(
    'current week counts use Monday inclusive and next Monday exclusive bounds',
    () {
      final now = DateTime(2024, 1, 10, 12);
      final weekStart = startOfCurrentWeek(now);
      final nextWeekStart = startOfNextWeek(now);
      final calculator = WorkoutStatisticsCalculator(clock: () => now);
      final sessions = [
        buildWorkoutSession(
          id: 'prev-week',
          startedAt: weekStart.subtract(const Duration(minutes: 1)),
          totalReps: 150,
          averageScore: 75,
        ),
        buildWorkoutSession(
          id: 'monday-range',
          startedAt: weekStart,
          totalReps: 40,
          averageScore: 80,
        ),
        buildWorkoutSession(
          id: 'wednesday-range',
          startedAt: weekStart.add(const Duration(days: 2, hours: 2)),
          exerciseType: 'push_up',
          totalReps: 30,
          averageScore: 90,
        ),
        buildWorkoutSession(
          id: 'thursday-hold',
          startedAt: weekStart.add(const Duration(days: 3)),
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
        ),
        buildWorkoutSession(
          id: 'next-week',
          startedAt: nextWeekStart,
          totalReps: 200,
          averageScore: 95,
        ),
      ];

      final statistics = calculator.calculate(sessions);

      expect(statistics.snapshotSessionCount, 5);
      expect(statistics.snapshotTotalReps, 420);
      expect(statistics.currentWeekAnalysisCount, 3);
      expect(statistics.currentWeekRepCount, 70);
    },
  );

  test(
    'limited evidence stays visible while aggregates use trusted or legacy sessions',
    () {
      final calculator = WorkoutStatisticsCalculator(
        clock: () => DateTime(2024, 1, 10, 12),
      );
      final sessions = [
        buildWorkoutSession(
          id: 'trusted',
          startedAt: DateTime(2024, 1, 8, 9),
          totalReps: 10,
          averageScore: 80,
          preparationOutcome: PreparationOutcome.passed,
          measurementQuality: SessionMeasurementQuality.high,
          averageMeasurementConfidence: 0.94,
          measurementSampleCount: 10,
        ),
        buildWorkoutSession(
          id: 'limited',
          startedAt: DateTime(2024, 1, 9, 9),
          totalReps: 100,
          averageScore: 100,
          preparationOutcome: PreparationOutcome.passed,
          measurementQuality: SessionMeasurementQuality.limited,
          averageMeasurementConfidence: 0.7,
          measurementSampleCount: 100,
        ),
        buildWorkoutSession(
          id: 'insufficient',
          startedAt: DateTime(2024, 1, 9, 12),
          totalReps: 1,
          averageScore: 99,
          preparationOutcome: PreparationOutcome.passed,
          measurementQuality: SessionMeasurementQuality.insufficient,
          averageMeasurementConfidence: 0.99,
          measurementSampleCount: 1,
        ),
        buildWorkoutSession(
          id: 'legacy',
          startedAt: DateTime(2024, 1, 10, 9),
          totalReps: 20,
          averageScore: 90,
        ),
      ];

      final statistics = calculator.calculate(sessions);

      expect(statistics.snapshotSessionCount, 4);
      expect(statistics.snapshotTotalReps, 30);
      expect(statistics.currentWeekAnalysisCount, 4);
      expect(statistics.currentWeekRepCount, 30);
      expect(statistics.averageScore, 85);
      expect(statistics.bestScore, 90);
      expect(statistics.bestAverageScore, 90);
      expect(
        statistics.chronologicalScoreSamples
            .map((sample) => sample.score)
            .toList(growable: false),
        <double>[80, 100, 90],
      );
      expect(
        statistics.chronologicalScoreSamples
            .map((sample) => sample.contributesToScoreAggregates)
            .toList(growable: false),
        <bool>[true, false, true],
      );
    },
  );
}
