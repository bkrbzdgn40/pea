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

    final bounds = _rangeBounds(range, now: now);

    return samples
        .where((sample) {
          final startedAt = _localStartedAt(sample);
          return !startedAt.isBefore(bounds.startInclusive) &&
              startedAt.isBefore(bounds.endExclusive);
        })
        .toList(growable: false);
  }

  ScoreTrendChartWindow? chartWindowForRange(
    ScoreTrendRange range, {
    required DateTime now,
    Iterable<WorkoutScoreSample>? source,
  }) {
    final resolvedSamples = (source ?? samples).toList(growable: false);
    if (resolvedSamples.isEmpty) {
      return null;
    }

    if (range != ScoreTrendRange.all) {
      final bounds = _rangeBounds(range, now: now);
      return ScoreTrendChartWindow(
        startInclusive: bounds.startInclusive,
        endExclusive: bounds.endExclusive,
        axisUnit: ScoreTrendAxisUnit.calendarDays,
      );
    }

    final points = detailPoints(source: resolvedSamples);
    return ScoreTrendChartWindow.forPoints(
      points,
      axisUnit: ScoreTrendAxisUnit.calendarMonths,
    );
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
          startedAt: sample.startedAt,
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
          startedAt: sample.startedAt,
        ),
    ];
  }
}

_ScoreTrendRangeBounds _rangeBounds(
  ScoreTrendRange range, {
  required DateTime now,
}) {
  final localNow = now.toLocal();
  final endExclusive = DateTime(
    localNow.year,
    localNow.month,
    localNow.day + 1,
  );
  final dayCount = switch (range) {
    ScoreTrendRange.sevenDays => 7,
    ScoreTrendRange.thirtyDays => 30,
    ScoreTrendRange.all => throw StateError(
      'All-time range has no fixed calendar-day boundary.',
    ),
  };

  return _ScoreTrendRangeBounds(
    startInclusive: endExclusive.subtract(Duration(days: dayCount)),
    endExclusive: endExclusive,
  );
}

class _ScoreTrendRangeBounds {
  const _ScoreTrendRangeBounds({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
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
