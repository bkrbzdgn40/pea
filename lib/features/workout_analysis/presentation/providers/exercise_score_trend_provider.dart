import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_statistics.dart';
import '../../application/workout_statistics_calculator.dart';
import '../../domain/models/exercise_type.dart';
import '../models/home_dashboard_data.dart';
import 'user_sessions_snapshot_provider.dart';

final exerciseScoreTrendProvider =
    FutureProvider.family<ExerciseScoreTrendData, ExerciseType>((
      ref,
      exercise,
    ) async {
      final snapshot = await ref.watch(userSessionsSnapshotProvider.future);
      final exerciseSessions = snapshot.sessions
          .where((session) => session.exerciseType == exercise.id)
          .toList(growable: false);
      final statistics = WorkoutStatisticsCalculator().calculate(
        exerciseSessions,
      );

      return ExerciseScoreTrendData(
        exercise: exercise,
        samples: snapshot.source == UserSessionsSnapshotSource.real
            ? statistics.chronologicalScoreSamples
            : const <WorkoutScoreSample>[],
        source: snapshot.source,
      );
    });

class ExerciseScoreTrendData {
  ExerciseScoreTrendData({
    required this.exercise,
    required List<WorkoutScoreSample> samples,
    required this.source,
  }) : samples = List<WorkoutScoreSample>.unmodifiable(samples);

  final ExerciseType exercise;
  final List<WorkoutScoreSample> samples;
  final UserSessionsSnapshotSource source;

  bool get hasRealData =>
      source == UserSessionsSnapshotSource.real && samples.isNotEmpty;

  double get bestAverageScore {
    return samples.fold<double>(
      0,
      (best, sample) => sample.score > best ? sample.score : best,
    );
  }

  List<WorkoutScoreSample> latestSamples({int limit = 7}) {
    if (limit <= 0 || samples.isEmpty) {
      return const <WorkoutScoreSample>[];
    }
    if (samples.length <= limit) {
      return samples;
    }
    return samples.sublist(samples.length - limit);
  }

  List<ScoreTrendPoint> latestPoints({
    int limit = 7,
    String Function(DateTime dateTime)? weekdayLabel,
  }) {
    final resolveWeekdayLabel = weekdayLabel ?? _weekdayLabel;
    return [
      for (final sample in latestSamples(limit: limit))
        ScoreTrendPoint(
          label: resolveWeekdayLabel(sample.startedAt.toLocal()),
          score: sample.score,
        ),
    ];
  }

  List<ScoreTrendPoint> detailPoints() {
    return [
      for (final sample in samples)
        ScoreTrendPoint(
          label: _dateLabel(sample.startedAt.toLocal()),
          score: sample.score,
        ),
    ];
  }
}

String _weekdayLabel(DateTime dateTime) {
  const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return labels[dateTime.weekday - 1];
}

String _dateLabel(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  return '$day.$month';
}
