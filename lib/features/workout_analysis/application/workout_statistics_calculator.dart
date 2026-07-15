import '../domain/models/workout_session.dart';
import 'engine_kind.dart';
import 'workout_statistics.dart';

class WorkoutStatisticsCalculator {
  WorkoutStatisticsCalculator({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  WorkoutStatistics calculate(List<WorkoutSession> sessions) {
    final scoreEligibleSessions = _scoreEligibleSessions(sessions);
    final chronologicalScoreSamples = scoreEligibleSessions
        .map(
          (session) => WorkoutScoreSample(
            startedAt: session.startedAt,
            score: session.averageScore,
          ),
        )
        .toList(growable: false);
    final currentWeekSessions = _currentWeekSessions(sessions);
    final totalEligibleAverageScore = scoreEligibleSessions.fold<double>(
      0,
      (total, session) => total + session.averageScore,
    );
    final bestScore = scoreEligibleSessions.fold<double>(
      0,
      (best, session) => session.bestScore > best ? session.bestScore : best,
    );
    final exerciseSessionCounts = <String, int>{};

    for (final session in sessions) {
      exerciseSessionCounts[session.exerciseType] =
          (exerciseSessionCounts[session.exerciseType] ?? 0) + 1;
    }

    return WorkoutStatistics(
      snapshotSessionCount: sessions.length,
      snapshotTotalReps: sessions.fold<int>(
        0,
        (total, session) => total + session.totalReps,
      ),
      currentWeekAnalysisCount: currentWeekSessions.length,
      currentWeekRepCount: currentWeekSessions.fold<int>(
        0,
        (total, session) => total + session.totalReps,
      ),
      chronologicalScoreSamples: chronologicalScoreSamples,
      averageScore: scoreEligibleSessions.isEmpty
          ? 0
          : totalEligibleAverageScore / scoreEligibleSessions.length,
      bestScore: bestScore,
      exerciseSessionCounts: exerciseSessionCounts,
    );
  }

  List<WorkoutSession> _scoreEligibleSessions(List<WorkoutSession> sessions) {
    final eligibleSessions = sessions
        .where(_isScoreEligible)
        .toList(growable: false);

    return eligibleSessions
      ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
  }

  bool _isScoreEligible(WorkoutSession session) {
    return session.analysisKind == EngineKind.rangeRep.name &&
        session.averageScore > 0;
  }

  List<WorkoutSession> _currentWeekSessions(List<WorkoutSession> sessions) {
    final bounds = _currentWeekBounds();

    return sessions
        .where((session) {
          final startedAt = session.startedAt.toLocal();

          return !startedAt.isBefore(bounds.start) &&
              startedAt.isBefore(bounds.end);
        })
        .toList(growable: false);
  }

  _CurrentWeekBounds _currentWeekBounds() {
    final now = _clock().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: now.weekday - 1));

    return _CurrentWeekBounds(
      start: start,
      end: start.add(const Duration(days: 7)),
    );
  }
}

class _CurrentWeekBounds {
  const _CurrentWeekBounds({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
