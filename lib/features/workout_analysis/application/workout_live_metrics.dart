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
    final romValues = reps
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

    final durations = reps
        .map((rep) => rep.observedDuration)
        .whereType<Duration>()
        .toList(growable: false);
    if (durations.isNotEmpty) {
      final averageMillis =
          durations.fold<int>(0, (sum, value) => sum + value.inMilliseconds) /
          durations.length;
      final averageDuration = Duration(milliseconds: averageMillis.round());
      builder
        ..set(ExerciseMetricRegistry.tempo, averageDuration)
        ..set(ExerciseMetricRegistry.repDuration, averageDuration);
    }

    return builder.build();
  }
}
