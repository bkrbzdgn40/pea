import '../../../workout_analysis/domain/models/exercise_type.dart';
import 'challenge_contribution.dart';
import 'challenge_evidence_quality.dart';
import 'challenge_metric.dart';

/// Aggregated trusted activity for one captured local calendar date.
class ActivityDaySummary {
  ActivityDaySummary({
    required this.ownerId,
    required this.localDate,
    required this.trustedSessionCount,
    required this.highReliabilitySessionCount,
    required Map<ExerciseType, int> validRepsByExercise,
    required Map<ExerciseType, double> holdSecondsByExercise,
    required Set<ExerciseType> exerciseTypes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : validRepsByExercise = Map.unmodifiable(validRepsByExercise),
       holdSecondsByExercise = Map.unmodifiable(holdSecondsByExercise),
       exerciseTypes = Set.unmodifiable(exerciseTypes),
       createdAtUtc = createdAt.toUtc(),
       updatedAtUtc = updatedAt.toUtc() {
    _validate();
  }

  factory ActivityDaySummary.fromContribution({
    required String ownerId,
    required ChallengeContribution contribution,
    required DateTime now,
  }) {
    final nowUtc = now.toUtc();
    return ActivityDaySummary(
      ownerId: ownerId,
      localDate: contribution.dailyWindow.key,
      trustedSessionCount: 0,
      highReliabilitySessionCount: 0,
      validRepsByExercise: const <ExerciseType, int>{},
      holdSecondsByExercise: const <ExerciseType, double>{},
      exerciseTypes: const <ExerciseType>{},
      createdAt: nowUtc,
      updatedAt: nowUtc,
    ).addContribution(contribution, now: nowUtc);
  }

  final String ownerId;
  final String localDate;
  final int trustedSessionCount;
  final int highReliabilitySessionCount;
  final Map<ExerciseType, int> validRepsByExercise;
  final Map<ExerciseType, double> holdSecondsByExercise;
  final Set<ExerciseType> exerciseTypes;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  bool get isEmpty =>
      trustedSessionCount == 0 &&
      highReliabilitySessionCount == 0 &&
      validRepsByExercise.isEmpty &&
      holdSecondsByExercise.isEmpty &&
      exerciseTypes.isEmpty;

  ActivityDaySummary addContribution(
    ChallengeContribution contribution, {
    required DateTime now,
  }) {
    _requireMatchingDate(contribution);
    final reps = Map<ExerciseType, int>.from(validRepsByExercise);
    final holds = Map<ExerciseType, double>.from(holdSecondsByExercise);

    switch (contribution.metric) {
      case ChallengeMetric.validRepetitions:
        reps.update(
          contribution.exerciseType,
          (value) => value + contribution.value.toInt(),
          ifAbsent: () => contribution.value.toInt(),
        );
      case ChallengeMetric.trustedHoldSeconds:
        holds.update(
          contribution.exerciseType,
          (value) => value + contribution.value,
          ifAbsent: () => contribution.value,
        );
    }

    return ActivityDaySummary(
      ownerId: ownerId,
      localDate: localDate,
      trustedSessionCount: trustedSessionCount + 1,
      highReliabilitySessionCount:
          highReliabilitySessionCount +
          (contribution.evidenceQuality == ChallengeEvidenceQuality.high
              ? 1
              : 0),
      validRepsByExercise: reps,
      holdSecondsByExercise: holds,
      exerciseTypes: <ExerciseType>{...reps.keys, ...holds.keys},
      createdAt: createdAtUtc,
      updatedAt: _nextUpdatedAt(now),
    );
  }

  ActivityDaySummary removeContribution(
    ChallengeContribution contribution, {
    required DateTime now,
  }) {
    _requireMatchingDate(contribution);
    if (trustedSessionCount <= 0) {
      throw StateError('Cannot remove a contribution from an empty day.');
    }
    if (contribution.evidenceQuality == ChallengeEvidenceQuality.high &&
        highReliabilitySessionCount <= 0) {
      throw StateError('High-reliability session count is inconsistent.');
    }

    final reps = Map<ExerciseType, int>.from(validRepsByExercise);
    final holds = Map<ExerciseType, double>.from(holdSecondsByExercise);

    switch (contribution.metric) {
      case ChallengeMetric.validRepetitions:
        final current = reps[contribution.exerciseType];
        final removed = contribution.value.toInt();
        if (current == null || current < removed) {
          throw StateError('Rep aggregate is smaller than the contribution.');
        }
        final next = current - removed;
        if (next == 0) {
          reps.remove(contribution.exerciseType);
        } else {
          reps[contribution.exerciseType] = next;
        }
      case ChallengeMetric.trustedHoldSeconds:
        final current = holds[contribution.exerciseType];
        if (current == null || current + _epsilon < contribution.value) {
          throw StateError('Hold aggregate is smaller than the contribution.');
        }
        final next = current - contribution.value;
        if (next.abs() <= _epsilon) {
          holds.remove(contribution.exerciseType);
        } else {
          holds[contribution.exerciseType] = next;
        }
    }

    return ActivityDaySummary(
      ownerId: ownerId,
      localDate: localDate,
      trustedSessionCount: trustedSessionCount - 1,
      highReliabilitySessionCount:
          highReliabilitySessionCount -
          (contribution.evidenceQuality == ChallengeEvidenceQuality.high
              ? 1
              : 0),
      validRepsByExercise: reps,
      holdSecondsByExercise: holds,
      exerciseTypes: <ExerciseType>{...reps.keys, ...holds.keys},
      createdAt: createdAtUtc,
      updatedAt: _nextUpdatedAt(now),
    );
  }

  DateTime _nextUpdatedAt(DateTime candidate) {
    final candidateUtc = candidate.toUtc();
    return candidateUtc.isBefore(updatedAtUtc) ? updatedAtUtc : candidateUtc;
  }

  void _requireMatchingDate(ChallengeContribution contribution) {
    final contributionDate = contribution.dailyWindow.key;
    if (contributionDate != localDate) {
      throw ArgumentError.value(
        contributionDate,
        'contribution',
        'Contribution belongs to a different activity day.',
      );
    }
  }

  void _validate() {
    if (ownerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty.');
    }
    if (!isValidActivityLocalDate(localDate)) {
      throw ArgumentError.value(
        localDate,
        'localDate',
        'Expected a real YYYY-MM-DD calendar date.',
      );
    }
    if (trustedSessionCount < 0 ||
        highReliabilitySessionCount < 0 ||
        highReliabilitySessionCount > trustedSessionCount) {
      throw ArgumentError('Invalid trusted session counters.');
    }
    if (updatedAtUtc.isBefore(createdAtUtc)) {
      throw ArgumentError('updatedAt must not be before createdAt.');
    }
    if (validRepsByExercise.values.any((value) => value <= 0)) {
      throw ArgumentError('Rep aggregates must be positive integers.');
    }
    if (holdSecondsByExercise.values.any(
      (value) => !value.isFinite || value <= 0,
    )) {
      throw ArgumentError('Hold aggregates must be finite and positive.');
    }
    if (validRepsByExercise.keys.any(holdSecondsByExercise.containsKey)) {
      throw ArgumentError('An exercise cannot use both progress metrics.');
    }
    final derivedExercises = <ExerciseType>{
      ...validRepsByExercise.keys,
      ...holdSecondsByExercise.keys,
    };
    if (derivedExercises.length != exerciseTypes.length ||
        !derivedExercises.containsAll(exerciseTypes)) {
      throw ArgumentError('exerciseTypes must match aggregate map keys.');
    }
    if (trustedSessionCount == 0 && derivedExercises.isNotEmpty) {
      throw ArgumentError('Empty session counters cannot contain volume.');
    }
    if (trustedSessionCount > 0 && derivedExercises.isEmpty) {
      throw ArgumentError('Trusted sessions must contain exercise volume.');
    }
    if (derivedExercises.length > trustedSessionCount) {
      throw ArgumentError(
        'Exercise diversity cannot exceed trusted session count.',
      );
    }
  }
}

const double _epsilon = 0.000001;

bool isValidActivityLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}
