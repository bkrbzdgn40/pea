import '../domain/models/session_measurement_evidence.dart';

class WorkoutScoreSample {
  const WorkoutScoreSample({
    required this.startedAt,
    required this.score,
    this.preparationOutcome = PreparationOutcome.legacyUnknown,
    this.measurementQuality = SessionMeasurementQuality.unknown,
    this.averageMeasurementConfidence,
    this.measurementSampleCount = 0,
    this.contributesToScoreAggregates = true,
  });

  final DateTime startedAt;
  final double score;
  final PreparationOutcome preparationOutcome;
  final SessionMeasurementQuality measurementQuality;
  final double? averageMeasurementConfidence;
  final int measurementSampleCount;
  final bool contributesToScoreAggregates;

  bool get hasEvidenceWarning =>
      preparationOutcome == PreparationOutcome.overridden ||
      measurementQuality == SessionMeasurementQuality.limited ||
      measurementQuality == SessionMeasurementQuality.insufficient;
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
    return chronologicalScoreSamples
        .where((sample) => sample.contributesToScoreAggregates)
        .fold<double>(
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
