import '../../domain/models/workout_session.dart';

enum HomeDashboardSource { loading, real, noUser, empty, error }

/// Aggregated values used by Home without exposing session query details.
class HomeDashboardData {
  const HomeDashboardData({
    required this.totalAnalyses,
    required this.averageScore,
    required this.thisWeekCount,
    required this.bestScore,
    required this.scoreTrend,
    required this.exerciseDistribution,
    required this.source,
    this.latestSession,
  });

  final int totalAnalyses;
  final int averageScore;
  final int thisWeekCount;
  final int bestScore;
  final List<ScoreTrendPoint> scoreTrend;
  final List<ExerciseDistributionItem> exerciseDistribution;
  final HomeDashboardSource source;
  final WorkoutSession? latestSession;

  factory HomeDashboardData.empty({
    HomeDashboardSource source = HomeDashboardSource.empty,
  }) {
    return HomeDashboardData(
      totalAnalyses: 0,
      averageScore: 0,
      thisWeekCount: 0,
      bestScore: 0,
      scoreTrend: const <ScoreTrendPoint>[],
      exerciseDistribution: const <ExerciseDistributionItem>[],
      source: source,
      latestSession: null,
    );
  }

  factory HomeDashboardData.fallback({
    HomeDashboardSource source = HomeDashboardSource.loading,
  }) {
    return HomeDashboardData.empty(source: source);
  }

  bool get hasRealData => source == HomeDashboardSource.real;

  String get sourceMessage {
    return switch (source) {
      HomeDashboardSource.loading => 'Oturum verisi yükleniyor',
      HomeDashboardSource.real => 'Gerçek oturum verisi',
      HomeDashboardSource.noUser => 'Kullanıcı oturumu bulunamadı',
      HomeDashboardSource.empty => 'Henüz oturum yok',
      HomeDashboardSource.error => 'Oturum verisi alınamadı',
    };
  }
}

class ScoreTrendPoint {
  const ScoreTrendPoint({
    required this.label,
    required this.score,
    this.startedAt,
  });

  final String label;
  final double score;
  final DateTime? startedAt;

  String get tooltipLabel {
    final localStartedAt = startedAt?.toLocal();
    if (localStartedAt == null) {
      return label;
    }

    final day = localStartedAt.day.toString().padLeft(2, '0');
    final month = localStartedAt.month.toString().padLeft(2, '0');
    final year = localStartedAt.year.toString();
    final hour = localStartedAt.hour.toString().padLeft(2, '0');
    final minute = localStartedAt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

enum ScoreTrendAxisUnit { calendarDays, calendarMonths }

class ScoreTrendChartWindow {
  ScoreTrendChartWindow({
    required this.startInclusive,
    required this.endExclusive,
    required this.axisUnit,
  }) : assert(endExclusive.isAfter(startInclusive));

  final DateTime startInclusive;
  final DateTime endExclusive;
  final ScoreTrendAxisUnit axisUnit;

  factory ScoreTrendChartWindow.forPoints(
    Iterable<ScoreTrendPoint> points, {
    ScoreTrendAxisUnit axisUnit = ScoreTrendAxisUnit.calendarDays,
  }) {
    final startedAtValues =
        points
            .map((point) => point.startedAt?.toLocal())
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort();
    if (startedAtValues.isEmpty) {
      throw ArgumentError.value(
        points,
        'points',
        'At least one point must include startedAt.',
      );
    }

    final first = startedAtValues.first;
    final last = startedAtValues.last;
    return switch (axisUnit) {
      ScoreTrendAxisUnit.calendarDays => ScoreTrendChartWindow(
        startInclusive: DateTime(first.year, first.month, first.day),
        endExclusive: DateTime(last.year, last.month, last.day + 1),
        axisUnit: axisUnit,
      ),
      ScoreTrendAxisUnit.calendarMonths => ScoreTrendChartWindow(
        startInclusive: DateTime(first.year, first.month),
        endExclusive: DateTime(last.year, last.month + 1),
        axisUnit: axisUnit,
      ),
    };
  }

  double get maxX {
    final unitCount = switch (axisUnit) {
      ScoreTrendAxisUnit.calendarDays => _calendarDayDifference(
        startInclusive,
        endExclusive,
      ).toDouble(),
      ScoreTrendAxisUnit.calendarMonths => _calendarMonthDifference(
        startInclusive,
        endExclusive,
      ).toDouble(),
    };
    return unitCount <= 1 ? 0.999999 : unitCount - 0.000001;
  }

  double positionFor(DateTime startedAt) {
    final localStartedAt = startedAt.toLocal();
    return switch (axisUnit) {
      ScoreTrendAxisUnit.calendarDays => _dayPosition(localStartedAt),
      ScoreTrendAxisUnit.calendarMonths => _monthPosition(localStartedAt),
    };
  }

  DateTime dateForPosition(double position) {
    final safePosition = position < 0
        ? 0.0
        : position > maxX
        ? maxX
        : position;
    return switch (axisUnit) {
      ScoreTrendAxisUnit.calendarDays => _dateForDayPosition(safePosition),
      ScoreTrendAxisUnit.calendarMonths => _dateForMonthPosition(safePosition),
    };
  }

  double _dayPosition(DateTime startedAt) {
    final dayStart = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final dayOffset = _calendarDayDifference(startInclusive, dayStart);
    return dayOffset + _fractionOfDay(startedAt);
  }

  double _monthPosition(DateTime startedAt) {
    final monthStart = DateTime(startedAt.year, startedAt.month);
    final monthOffset = _calendarMonthDifference(startInclusive, monthStart);
    final daysInMonth = DateTime(startedAt.year, startedAt.month + 1, 0).day;
    return monthOffset +
        (startedAt.day - 1 + _fractionOfDay(startedAt)) / daysInMonth;
  }

  DateTime _dateForDayPosition(double position) {
    final wholeDays = position.floor();
    final fraction = position - wholeDays;
    final dayStart = DateTime(
      startInclusive.year,
      startInclusive.month,
      startInclusive.day + wholeDays,
    );
    return dayStart.add(
      Duration(microseconds: (fraction * _microsecondsPerDay).round()),
    );
  }

  DateTime _dateForMonthPosition(double position) {
    final wholeMonths = position.floor();
    final fraction = position - wholeMonths;
    final monthStart = DateTime(
      startInclusive.year,
      startInclusive.month + wholeMonths,
    );
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final dayPosition = fraction * daysInMonth;
    final wholeDays = dayPosition.floor();
    final dayFraction = dayPosition - wholeDays;
    final dayStart = DateTime(monthStart.year, monthStart.month, 1 + wholeDays);
    return dayStart.add(
      Duration(microseconds: (dayFraction * _microsecondsPerDay).round()),
    );
  }
}

const int _microsecondsPerDay = 24 * 60 * 60 * 1000 * 1000;

int _calendarDayDifference(DateTime start, DateTime end) {
  final normalizedStart = DateTime.utc(start.year, start.month, start.day);
  final normalizedEnd = DateTime.utc(end.year, end.month, end.day);
  return normalizedEnd.difference(normalizedStart).inDays;
}

int _calendarMonthDifference(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + end.month - start.month;
}

double _fractionOfDay(DateTime dateTime) {
  final elapsedMicroseconds =
      dateTime.hour * 60 * 60 * 1000 * 1000 +
      dateTime.minute * 60 * 1000 * 1000 +
      dateTime.second * 1000 * 1000 +
      dateTime.millisecond * 1000 +
      dateTime.microsecond;
  return elapsedMicroseconds / _microsecondsPerDay;
}

class ExerciseDistributionItem {
  const ExerciseDistributionItem({
    required this.label,
    required this.value,
    this.exerciseId,
    this.groupedExerciseCount = 0,
  });

  final String label;
  final double value;
  final String? exerciseId;
  final int groupedExerciseCount;

  bool get isRemainder => groupedExerciseCount > 0;
}
