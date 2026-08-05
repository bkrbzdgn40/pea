import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_statistics.dart';
import '../../application/workout_statistics_calculator.dart';
import '../../domain/models/exercise_type.dart';
import '../models/home_dashboard_data.dart';
import 'user_sessions_snapshot_provider.dart';

final scoreTrendClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

enum ScoreTrendRange { sevenDays, thirtyDays, all }

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

  double get bestAverageScore => bestAverageScoreFor(samples);

  List<WorkoutScoreSample> samplesForRange(
    ScoreTrendRange range, {
    required DateTime now,
  }) {
    if (range == ScoreTrendRange.all || samples.isEmpty) {
      return samples;
    }

    final localNow = now.toLocal();
    final startOfTomorrow = DateTime(
      localNow.year,
      localNow.month,
      localNow.day + 1,
    );
    final dayCount = switch (range) {
      ScoreTrendRange.sevenDays => 7,
      ScoreTrendRange.thirtyDays => 30,
      ScoreTrendRange.all => throw StateError(
        'All-time range has no boundary.',
      ),
    };
    final startInclusive = startOfTomorrow.subtract(Duration(days: dayCount));

    return samples
        .where((sample) {
          final startedAt = _localStartedAt(sample);
          return !startedAt.isBefore(startInclusive) &&
              startedAt.isBefore(startOfTomorrow);
        })
        .toList(growable: false);
  }

  double bestAverageScoreFor(Iterable<WorkoutScoreSample> source) {
    return source.fold<double>(
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

  List<ScoreTrendPoint> detailPoints({Iterable<WorkoutScoreSample>? source}) {
    final resolvedSamples = source ?? samples;
    return [
      for (final sample in resolvedSamples)
        ScoreTrendPoint(
          label: _dateLabel(_localStartedAt(sample)),
          score: sample.score,
        ),
    ];
  }
}

DateTime _localStartedAt(WorkoutScoreSample sample) {
  return sample.startedAt.toLocal();
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
