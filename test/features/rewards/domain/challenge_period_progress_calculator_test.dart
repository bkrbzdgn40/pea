import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/activity_day_summary.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';
import 'package:pose_estimation_app/features/rewards/domain/challenge_period_progress_calculator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const calculator = ChallengePeriodProgressCalculator();

  test('sums only the selected exercise across the period', () {
    final definition = const ChallengeCatalog().definitionFor(
      ExerciseType.pushUp,
    );
    final window = ChallengePeriodWindow.forInstant(
      period: ChallengePeriod.weekly,
      instant: DateTime.utc(2026, 8, 7),
      timezoneOffset: Duration.zero,
    );

    final total = calculator.calculate(
      definition: definition,
      window: window,
      activityDays: <ActivityDaySummary>[
        _day('2026-08-03', pushUps: 20, squats: 50),
        _day('2026-08-05', pushUps: 25),
      ],
    );

    expect(total, 45);
  });

  test('rejects duplicate or out-of-window day aggregates', () {
    final definition = const ChallengeCatalog().definitionFor(
      ExerciseType.pushUp,
    );
    final window = ChallengePeriodWindow.forInstant(
      period: ChallengePeriod.daily,
      instant: DateTime.utc(2026, 8, 7),
      timezoneOffset: Duration.zero,
    );
    final day = _day('2026-08-07', pushUps: 10);

    expect(
      () => calculator.calculate(
        definition: definition,
        window: window,
        activityDays: <ActivityDaySummary>[day, day],
      ),
      throwsStateError,
    );
    expect(
      () => calculator.calculate(
        definition: definition,
        window: window,
        activityDays: <ActivityDaySummary>[_day('2026-08-08', pushUps: 10)],
      ),
      throwsStateError,
    );
  });
}

ActivityDaySummary _day(String localDate, {int pushUps = 0, int squats = 0}) {
  final reps = <ExerciseType, int>{
    if (pushUps > 0) ExerciseType.pushUp: pushUps,
    if (squats > 0) ExerciseType.squat: squats,
  };
  return ActivityDaySummary(
    ownerId: 'user-1',
    localDate: localDate,
    trustedSessionCount: reps.length,
    highReliabilitySessionCount: reps.length,
    validRepsByExercise: reps,
    holdSecondsByExercise: const <ExerciseType, double>{},
    exerciseTypes: reps.keys.toSet(),
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 1),
  );
}
