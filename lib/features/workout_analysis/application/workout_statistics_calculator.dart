import '../domain/models/workout_session.dart';
import '../domain/session_evidence_eligibility_policy.dart';
import 'workout_statistics.dart';

class WorkoutStatisticsCalculator {
  WorkoutStatisticsCalculator({
    DateTime Function()? clock,
    SessionEvidenceEligibilityPolicy evidencePolicy =
        const SessionEvidenceEligibilityPolicy(),
  }) : _clock = clock ?? DateTime.now,
       _evidencePolicy = evidencePolicy;

  final DateTime Function() _clock;
  final SessionEvidenceEligibilityPolicy _evidencePolicy;

  WorkoutStatistics calculate(List<WorkoutSession> sessions) {
    final trendSessions =
        sessions
            .where(_evidencePolicy.appearsInScoreTrend)
            .toList(growable: false)
          ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
    final aggregateScoreSessions = sessions
        .where(_evidencePolicy.contributesToScoreAggregates)
        .toList(growable: false);
    final chronologicalScoreSamples = trendSessions
        .map(
          (session) => WorkoutScoreSample(
            startedAt: session.startedAt,
            score: session.averageScore,
            preparationOutcome: session.preparationOutcome,
            measurementQuality: session.measurementQuality,
            averageMeasurementConfidence: session.averageMeasurementConfidence,
            measurementSampleCount: session.measurementSampleCount,
            contributesToScoreAggregates: _evidencePolicy
                .contributesToScoreAggregates(session),
          ),
        )
        .toList(growable: false);
    final currentWeekSessions = _currentWeekSessions(sessions);
    final totalEligibleAverageScore = aggregateScoreSessions.fold<double>(
      0,
      (total, session) => total + session.averageScore,
    );
    final bestScore = aggregateScoreSessions.fold<double>(
      0,
      (best, session) => session.bestScore > best ? session.bestScore : best,
    );
    final exerciseSessionCounts = <String, int>{};

    for (final session in sessions) {
      exerciseSessionCounts[session.exerciseType] =
          (exerciseSessionCounts[session.exerciseType] ?? 0) + 1;
    }

    return WorkoutStatistics(
      snapshotSessionCount: sessions
          .where(_evidencePolicy.countsAsCompletedSession)
          .length,
      snapshotTotalReps: sessions
          .where(_evidencePolicy.contributesToRepetitionVolume)
          .fold<int>(0, (total, session) => total + session.totalReps),
      currentWeekAnalysisCount: currentWeekSessions
          .where(_evidencePolicy.countsAsCompletedSession)
          .length,
      currentWeekRepCount: currentWeekSessions
          .where(_evidencePolicy.contributesToRepetitionVolume)
          .fold<int>(0, (total, session) => total + session.totalReps),
      chronologicalScoreSamples: chronologicalScoreSamples,
      averageScore: aggregateScoreSessions.isEmpty
          ? 0
          : totalEligibleAverageScore / aggregateScoreSessions.length,
      bestScore: bestScore,
      exerciseSessionCounts: exerciseSessionCounts,
    );
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
