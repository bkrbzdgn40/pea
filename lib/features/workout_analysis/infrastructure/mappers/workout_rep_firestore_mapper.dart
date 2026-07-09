import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';

/// Maps rep subcollection documents between Firestore and the domain model.
class WorkoutRepFirestoreMapper {
  const WorkoutRepFirestoreMapper();

  String documentIdFor(WorkoutRep rep) {
    return rep.stableId;
  }

  Map<String, dynamic> toDocument({
    required WorkoutRep rep,
    required WorkoutSession session,
  }) {
    final createdAt = rep.recordedAt ?? session.endedAt;
    final observedDuration = rep.observedDuration;

    return <String, dynamic>{
      'id': documentIdFor(rep),
      'ownerId': session.ownerId,
      'sessionId': session.id,
      'exerciseType': rep.exerciseType,
      'analysisKind': rep.analysisKind,
      'repIndex': rep.repIndex,
      'score': rep.score,
      'isValid': rep.isValidatedAsValid,
      'validationStatus': rep.validationStatus,
      'invalidReason': rep.primaryValidationReason,
      'validationReasons': rep.validationReasons.toList(growable: false),
      // Full rep start timestamps are not retained by the current runtime yet.
      'endedAt': rep.recordedAt == null
          ? null
          : Timestamp.fromDate(rep.recordedAt!),
      'durationSeconds': observedDuration == null
          ? null
          : observedDuration.inMilliseconds / 1000.0,
      'minPrimaryMetric': rep.minPrimaryMetric,
      // Max primary metric is intentionally omitted until the live runtime
      // carries it through completed-rep data.
      'worstFormMetric': rep.worstFormMetric,
      'descentMillis': rep.descentMillis,
      'ascentMillis': rep.ascentMillis,
      'hadFormViolation': rep.hadFormViolation,
      'hadCoverageDrop': rep.hadCoverageDrop,
      'switchedSideDuringRep': rep.switchedSideDuringRep,
      'completedPhaseSequence': rep.completedPhaseSequence,
      'selectedSide': rep.selectedSideLabel,
      'feedback': rep.feedback,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  WorkoutRep fromDocument(Map<String, dynamic> data) {
    final validationReasons = _readStringList(data['validationReasons']);
    final invalidReason = _readNullableString(data['invalidReason']);
    final validationStatus =
        _readNullableString(data['validationStatus']) ??
        _fallbackValidationStatus(
          isValid: data['isValid'],
          invalidReason: invalidReason,
          validationReasons: validationReasons,
        );

    return WorkoutRep.fromMap(<String, Object?>{
      'repIndex': data['repIndex'],
      'exerciseType': data['exerciseType'],
      'analysisKind': data['analysisKind'],
      'recordedAt': _toPlainDate(data['endedAt'] ?? data['createdAt']),
      'validationStatus': validationStatus,
      'validationReasons': validationReasons.isNotEmpty
          ? validationReasons
          : invalidReason == null
          ? const <String>[]
          : <String>[invalidReason],
      'score': data['score'],
      'minPrimaryMetric': data['minPrimaryMetric'],
      'worstFormMetric': data['worstFormMetric'],
      'descentMillis': data['descentMillis'],
      'ascentMillis': data['ascentMillis'],
      'feedback': data['feedback'],
      'hadFormViolation': data['hadFormViolation'],
      'hadCoverageDrop': data['hadCoverageDrop'],
      'switchedSideDuringRep': data['switchedSideDuringRep'],
      'completedPhaseSequence': data['completedPhaseSequence'],
      'selectedSide': data['selectedSide'],
    });
  }

  String? _fallbackValidationStatus({
    required Object? isValid,
    required Object? invalidReason,
    required List<String> validationReasons,
  }) {
    if (isValid is bool) {
      if (isValid) {
        return 'valid';
      }

      if (validationReasons.isNotEmpty ||
          invalidReason is String && invalidReason.isNotEmpty) {
        return 'invalid';
      }

      return 'unknown';
    }

    if (invalidReason is String && invalidReason.isNotEmpty) {
      return 'invalid';
    }

    return null;
  }

  String? _readNullableString(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    throw const FormatException('Expected nullable string.');
  }

  List<String> _readStringList(Object? value) {
    if (value == null) {
      return const <String>[];
    }

    if (value is Iterable) {
      return value.whereType<String>().toList(growable: false);
    }

    throw const FormatException('Expected string list.');
  }

  Object? _toPlainDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return value;
  }
}
