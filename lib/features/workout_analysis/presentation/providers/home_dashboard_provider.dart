import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/workout_statistics.dart';
import '../../application/workout_statistics_calculator.dart';
import '../../domain/models/workout_session.dart';
import '../models/home_dashboard_data.dart';
import 'settings_provider.dart';
import 'user_sessions_snapshot_provider.dart';

/// Builds Home dashboard aggregates from the shared session snapshot.
final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);
  final localizations = ref.watch(appLocalizationsProvider);

  return switch (snapshot.source) {
    UserSessionsSnapshotSource.real => _buildDashboardData(
      snapshot.sessions,
      localizations,
    ),
    UserSessionsSnapshotSource.noUser => HomeDashboardData.empty(
      source: HomeDashboardSource.noUser,
    ),
    UserSessionsSnapshotSource.empty => HomeDashboardData.empty(
      source: HomeDashboardSource.empty,
    ),
    UserSessionsSnapshotSource.error => HomeDashboardData.empty(
      source: HomeDashboardSource.error,
    ),
  };
});

HomeDashboardData _buildDashboardData(
  List<WorkoutSession> sessions,
  AppLocalizations localizations,
) {
  final statistics = WorkoutStatisticsCalculator().calculate(sessions);

  return HomeDashboardData(
    totalAnalyses: statistics.snapshotSessionCount,
    averageScore: statistics.averageScore.round(),
    thisWeekCount: statistics.currentWeekAnalysisCount,
    bestScore: statistics.bestScore.round(),
    scoreTrend: _buildScoreTrend(
      statistics.latestScoreSamples(),
      localizations,
    ),
    exerciseDistribution: _buildExerciseDistribution(
      statistics.exerciseSessionCounts,
      statistics.snapshotSessionCount,
      localizations,
    ),
    source: HomeDashboardSource.real,
    latestSession: _latestSession(sessions),
  );
}

List<ScoreTrendPoint> _buildScoreTrend(
  List<WorkoutScoreSample> samples,
  AppLocalizations localizations,
) {
  return [
    for (final sample in samples)
      ScoreTrendPoint(
        label: localizations.weekdayShort(sample.startedAt.toLocal().weekday),
        score: sample.score,
        startedAt: sample.startedAt,
        preparationOutcome: sample.preparationOutcome,
        measurementQuality: sample.measurementQuality,
        averageMeasurementConfidence: sample.averageMeasurementConfidence,
        measurementSampleCount: sample.measurementSampleCount,
        contributesToScoreAggregates: sample.contributesToScoreAggregates,
      ),
  ];
}

List<ExerciseDistributionItem> _buildExerciseDistribution(
  Map<String, int> exerciseSessionCounts,
  int totalSessionCount,
  AppLocalizations localizations,
) {
  if (exerciseSessionCounts.isEmpty || totalSessionCount <= 0) {
    return const <ExerciseDistributionItem>[];
  }

  final sortedEntries = exerciseSessionCounts.entries.toList()
    ..sort((left, right) {
      final countComparison = right.value.compareTo(left.value);
      return countComparison != 0
          ? countComparison
          : left.key.compareTo(right.key);
    });
  final visibleEntries = sortedEntries.take(4).toList(growable: false);
  final hiddenEntries = sortedEntries.skip(4).toList(growable: false);
  final groupedEntries = <_DistributionCount>[
    for (final entry in visibleEntries)
      _DistributionCount(
        label: localizations.exerciseTitle(entry.key),
        exerciseId: entry.key,
        count: entry.value,
      ),
    if (hiddenEntries.isNotEmpty)
      _DistributionCount(
        label: localizations.exerciseDistributionOther,
        count: hiddenEntries.fold<int>(
          0,
          (total, entry) => total + entry.value,
        ),
        groupedExerciseCount: hiddenEntries.length,
      ),
  ];
  final percentages = _wholePercentages(
    groupedEntries.map((item) => item.count).toList(growable: false),
  );

  return [
    for (var index = 0; index < groupedEntries.length; index++)
      ExerciseDistributionItem(
        label: groupedEntries[index].label,
        value: percentages[index].toDouble(),
        exerciseId: groupedEntries[index].exerciseId,
        groupedExerciseCount: groupedEntries[index].groupedExerciseCount,
      ),
  ];
}

List<int> _wholePercentages(List<int> counts) {
  final total = counts.fold<int>(0, (sum, count) => sum + count);
  if (counts.isEmpty || total <= 0) {
    return const <int>[];
  }

  final rawPercentages = [for (final count in counts) count * 100 / total];
  final percentages = [
    for (final percentage in rawPercentages) percentage.floor(),
  ];
  var remaining = 100 - percentages.fold<int>(0, (sum, value) => sum + value);
  final allocationOrder = List<int>.generate(counts.length, (index) => index)
    ..sort((left, right) {
      final leftRemainder = rawPercentages[left] - percentages[left];
      final rightRemainder = rawPercentages[right] - percentages[right];
      final remainderComparison = rightRemainder.compareTo(leftRemainder);
      return remainderComparison != 0
          ? remainderComparison
          : left.compareTo(right);
    });

  for (final index in allocationOrder) {
    if (remaining == 0) {
      break;
    }
    percentages[index] += 1;
    remaining -= 1;
  }

  return percentages;
}

class _DistributionCount {
  const _DistributionCount({
    required this.label,
    required this.count,
    this.exerciseId,
    this.groupedExerciseCount = 0,
  });

  final String label;
  final String? exerciseId;
  final int count;
  final int groupedExerciseCount;
}

WorkoutSession? _latestSession(List<WorkoutSession> sessions) {
  if (sessions.isEmpty) {
    return null;
  }

  return sessions.reduce((latest, candidate) {
    return candidate.startedAt.isAfter(latest.startedAt) ? candidate : latest;
  });
}
