import '../domain/models/workout_rep.dart';
import '../domain/models/workout_session.dart';
import 'exercise_metric_registry.dart';

/// Canonical metric payload used by the live analysis UI and the immediate
/// post-session summary flow.
///
/// The persisted [WorkoutSession] model intentionally remains backward
/// compatible. Rich metrics that are available only while an analysis engine
/// is alive can still reach the summary screen through this immutable snapshot.
class WorkoutLiveMetricsSnapshot {
  const WorkoutLiveMetricsSnapshot({
    required this.frameMetrics,
    required this.sessionMetrics,
    this.leftRepCount,
    this.rightRepCount,
    this.tempoConsistencyScore,
    this.fastestRepDuration,
    this.slowestRepDuration,
  });

  final ExerciseMetricSnapshot frameMetrics;
  final ExerciseMetricSnapshot sessionMetrics;
  final int? leftRepCount;
  final int? rightRepCount;
  final double? tempoConsistencyScore;
  final Duration? fastestRepDuration;
  final Duration? slowestRepDuration;

  bool get hasBilateralRepCounts =>
      leftRepCount != null && rightRepCount != null;
}

/// Rebuilds canonical session metrics from a persisted workout session when a
/// richer live snapshot is unavailable (for example after process restart).
class WorkoutSessionMetricSnapshotBuilder {
  const WorkoutSessionMetricSnapshotBuilder();

  ExerciseMetricSnapshot build(WorkoutSession session) {
    final builder = ExerciseMetricSnapshotBuilder(
      scope: ExerciseMetricScope.session,
    );

    if (session.isHoldSession) {
      builder.set(
        ExerciseMetricRegistry.holdDuration,
        Duration(milliseconds: (session.totalHoldSeconds * 1000).round()),
      );
      return builder.build();
    }

    builder.set(ExerciseMetricRegistry.repetitionCount, session.totalReps);

    final reps = session.reps ?? const <WorkoutRep>[];
    final acceptedReps = reps
        .where((rep) => !rep.isValidatedAsInvalid)
        .toList(growable: false);
    final romValues = acceptedReps
        .map((rep) => rep.primaryRom)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);
    if (romValues.isNotEmpty) {
      builder.set(
        ExerciseMetricRegistry.rangeOfMotion,
        romValues.reduce((sum, value) => sum + value) / romValues.length,
      );
    }

    final tempoDurations = acceptedReps
        .where(
          (rep) => rep.isTempoMeasurementEligible && rep.hasTempoCoachingResult,
        )
        .map((rep) => rep.observedDuration)
        .whereType<Duration>()
        .where((duration) => duration.inMilliseconds > 0)
        .toList(growable: false);
    if (tempoDurations.isNotEmpty) {
      final totalMillis = tempoDurations.fold<int>(
        0,
        (sum, duration) => sum + duration.inMilliseconds,
      );
      builder.set(
        ExerciseMetricRegistry.tempo,
        Duration(milliseconds: (totalMillis / tempoDurations.length).round()),
      );
    }

    return builder.build();
  }
}
