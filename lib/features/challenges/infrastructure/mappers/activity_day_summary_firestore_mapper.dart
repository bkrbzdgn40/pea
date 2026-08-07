import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/activity_day_summary.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';

class ActivityDaySummaryFirestoreMapper {
  const ActivityDaySummaryFirestoreMapper();

  Map<String, Object?> toDocument(ActivityDaySummary summary) {
    final sortedReps = summary.validRepsByExercise.entries.toList()
      ..sort((left, right) => left.key.id.compareTo(right.key.id));
    final sortedHolds = summary.holdSecondsByExercise.entries.toList()
      ..sort((left, right) => left.key.id.compareTo(right.key.id));
    final sortedExercises = summary.exerciseTypes.toList()
      ..sort((left, right) => left.id.compareTo(right.id));

    return <String, Object?>{
      'id': summary.localDate,
      'ownerId': summary.ownerId,
      'localDate': summary.localDate,
      'trustedSessionCount': summary.trustedSessionCount,
      'highReliabilitySessionCount': summary.highReliabilitySessionCount,
      'validRepsByExercise': <String, int>{
        for (final entry in sortedReps) entry.key.id: entry.value,
      },
      'holdSecondsByExercise': <String, double>{
        for (final entry in sortedHolds) entry.key.id: entry.value,
      },
      'exerciseTypes': sortedExercises
          .map((exercise) => exercise.id)
          .toList(growable: false),
      'createdAt': Timestamp.fromDate(summary.createdAtUtc),
      'updatedAt': Timestamp.fromDate(summary.updatedAtUtc),
    };
  }

  ActivityDaySummary fromDocument({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final id = data['id'];
    final ownerId = data['ownerId'];
    final localDate = data['localDate'];
    final trustedSessionCount = data['trustedSessionCount'];
    final highReliabilitySessionCount = data['highReliabilitySessionCount'];
    final repsData = data['validRepsByExercise'];
    final holdsData = data['holdSecondsByExercise'];
    final exerciseData = data['exerciseTypes'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];

    if (id is! String ||
        id != documentId ||
        ownerId is! String ||
        ownerId.isEmpty ||
        localDate is! String ||
        localDate != documentId ||
        trustedSessionCount is! int ||
        highReliabilitySessionCount is! int ||
        repsData is! Map ||
        holdsData is! Map ||
        exerciseData is! List ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp) {
      throw const FormatException('Invalid activity day document.');
    }

    final reps = <ExerciseType, int>{};
    for (final entry in repsData.entries) {
      final exercise = entry.key is String
          ? ExerciseType.fromIdOrNull(entry.key as String)
          : null;
      if (exercise == null || entry.value is! int) {
        throw const FormatException('Invalid rep activity aggregate.');
      }
      reps[exercise] = entry.value as int;
    }

    final holds = <ExerciseType, double>{};
    for (final entry in holdsData.entries) {
      final exercise = entry.key is String
          ? ExerciseType.fromIdOrNull(entry.key as String)
          : null;
      final value = entry.value;
      if (exercise == null || value is! num) {
        throw const FormatException('Invalid hold activity aggregate.');
      }
      holds[exercise] = value.toDouble();
    }

    final exercises = <ExerciseType>{};
    for (final value in exerciseData) {
      final exercise = value is String
          ? ExerciseType.fromIdOrNull(value)
          : null;
      if (exercise == null || !exercises.add(exercise)) {
        throw const FormatException('Invalid activity exercise list.');
      }
    }

    try {
      return ActivityDaySummary(
        ownerId: ownerId,
        localDate: localDate,
        trustedSessionCount: trustedSessionCount,
        highReliabilitySessionCount: highReliabilitySessionCount,
        validRepsByExercise: reps,
        holdSecondsByExercise: holds,
        exerciseTypes: exercises,
        createdAt: createdAt.toDate(),
        updatedAt: updatedAt.toDate(),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid activity day document: $error');
    }
  }
}
