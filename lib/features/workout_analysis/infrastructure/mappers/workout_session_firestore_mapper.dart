import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/workout_session.dart';

/// Maps session summary documents between Firestore and the domain model.
class WorkoutSessionFirestoreMapper {
  const WorkoutSessionFirestoreMapper();

  Map<String, dynamic> toDocument(WorkoutSession session) {
    final now = DateTime.now();
    final createdAt = session.createdAt ?? now;
    final updatedAt = session.updatedAt ?? now;

    return <String, dynamic>{
      'id': session.id,
      'ownerId': session.ownerId,
      'exerciseType': session.exerciseType,
      'analysisKind': session.analysisKind,
      'startedAt': Timestamp.fromDate(session.startedAt),
      'endedAt': Timestamp.fromDate(session.endedAt),
      'durationSeconds': session.durationSec,
      'totalReps': session.totalReps,
      'validReps': _resolveValidRepCount(session),
      'invalidReps': _resolveInvalidRepCount(session),
      'averageScore': session.averageScore,
      'bestScore': session.bestScore,
      'worstScore': _resolveWorstScore(session),
      'formWarningCount': session.formWarningCount,
      'holdDurationSeconds': session.totalHoldSeconds,
      'bestHoldSeconds': session.bestHoldSeconds,
      'holdFormBreakCount': session.formBreakCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  WorkoutSession fromDocument(
    Map<String, dynamic> data, {
    required String fallbackId,
    required String fallbackOwnerId,
  }) {
    return WorkoutSession.fromMap(<String, Object?>{
      'id': data['id'] ?? fallbackId,
      'ownerId': data['ownerId'] ?? fallbackOwnerId,
      'exerciseType': data['exerciseType'],
      'analysisKind': data['analysisKind'],
      'startedAt': _toPlainDate(data['startedAt']),
      'endedAt': _toPlainDate(data['endedAt']),
      'durationSeconds': data['durationSeconds'] ?? data['durationSec'],
      'totalReps': data['totalReps'],
      'validReps': data['validReps'],
      'invalidReps': data['invalidReps'],
      'averageScore': data['averageScore'],
      'bestScore': data['bestScore'],
      'worstScore': data['worstScore'],
      'formWarningCount': data['formWarningCount'],
      'holdDurationSeconds':
          data['holdDurationSeconds'] ?? data['totalHoldSeconds'],
      'bestHoldSeconds': data['bestHoldSeconds'],
      'holdFormBreakCount':
          data['holdFormBreakCount'] ?? data['formBreakCount'],
      'createdAt': _toPlainDate(data['createdAt']),
      'updatedAt': _toPlainDate(data['updatedAt']),
    });
  }

  int _resolveValidRepCount(WorkoutSession session) {
    final reps = session.reps;
    if (reps == null) {
      return session.validReps;
    }

    return reps.where((rep) => rep.isValidatedAsValid).length;
  }

  int _resolveInvalidRepCount(WorkoutSession session) {
    final reps = session.reps;
    if (reps == null) {
      return session.invalidReps;
    }

    return reps.where((rep) => rep.isValidatedAsInvalid).length;
  }

  double _resolveWorstScore(WorkoutSession session) {
    final scoredReps = session.reps
        ?.map((rep) => rep.score)
        .whereType<double>()
        .toList(growable: false);
    if (scoredReps == null || scoredReps.isEmpty) {
      return session.worstScore;
    }

    return scoredReps.reduce((value, next) => value < next ? value : next);
  }

  Object? _toPlainDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return value;
  }
}
