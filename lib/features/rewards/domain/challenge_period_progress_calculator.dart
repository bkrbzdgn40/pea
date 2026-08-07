import '../../challenges/domain/models/activity_day_summary.dart';
import '../../challenges/domain/models/challenge_definition.dart';
import '../../challenges/domain/models/challenge_metric.dart';
import '../../challenges/domain/models/challenge_period_window.dart';

/// Sums trusted daily aggregates for one challenge period.
class ChallengePeriodProgressCalculator {
  const ChallengePeriodProgressCalculator();

  double calculate({
    required ChallengeDefinition definition,
    required ChallengePeriodWindow window,
    required Iterable<ActivityDaySummary> activityDays,
  }) {
    var total = 0.0;
    final seenDates = <String>{};
    for (final day in activityDays) {
      if (!seenDates.add(day.localDate)) {
        throw StateError('Duplicate activity day ${day.localDate}.');
      }
      if (day.localDate.compareTo(window.startLocalDateKey) < 0 ||
          day.localDate.compareTo(window.endLocalDateExclusiveKey) >= 0) {
        throw StateError(
          'Activity day ${day.localDate} falls outside ${window.key}.',
        );
      }
      total += switch (definition.metric) {
        ChallengeMetric.validRepetitions =>
          day.validRepsByExercise[definition.exerciseType]?.toDouble() ?? 0,
        ChallengeMetric.trustedHoldSeconds =>
          day.holdSecondsByExercise[definition.exerciseType] ?? 0,
      };
    }
    return total;
  }
}
