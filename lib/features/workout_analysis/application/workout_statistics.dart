class WorkoutScoreSample {
  const WorkoutScoreSample({required this.startedAt, required this.score});

  final DateTime startedAt;
  final double score;
}

class WorkoutStatistics {
  WorkoutStatistics({
    required this.snapshotSessionCount,
    required this.snapshotTotalReps,
    required this.currentWeekAnalysisCount,
    required this.currentWeekRepCount,
    required List<WorkoutScoreSample> chronologicalScoreSamples,
    required this.averageScore,
    required this.bestScore,
    required Map<String, int> exerciseSessionCounts,
  }) : chronologicalScoreSamples = List<WorkoutScoreSample>.unmodifiable(
         chronologicalScoreSamples,
       ),
       exerciseSessionCounts = Map<String, int>.unmodifiable(
         exerciseSessionCounts,
       );

  final int snapshotSessionCount;
  final int snapshotTotalReps;
  final int currentWeekAnalysisCount;
  final int currentWeekRepCount;
  final List<WorkoutScoreSample> chronologicalScoreSamples;
  final double averageScore;
  final double bestScore;
  final Map<String, int> exerciseSessionCounts;

  double get bestAverageScore {
    return chronologicalScoreSamples.fold<double>(
      0,
      (best, sample) => sample.score > best ? sample.score : best,
    );
  }

  List<WorkoutScoreSample> latestScoreSamples({int limit = 7}) {
    if (limit <= 0 || chronologicalScoreSamples.isEmpty) {
      return const <WorkoutScoreSample>[];
    }

    if (chronologicalScoreSamples.length <= limit) {
      return chronologicalScoreSamples;
    }

    return chronologicalScoreSamples.sublist(
      chronologicalScoreSamples.length - limit,
    );
  }
}
