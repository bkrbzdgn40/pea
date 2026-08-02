import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/remote/firestore_workout_write_diagnostics.dart';

void main() {
  group('FirestoreWorkoutWriteDiagnostics', () {
    test('accepts rule-compatible session and rep payloads', () {
      final session = _validSessionPayload();
      final rep = _validRepPayload();

      expect(
        FirestoreWorkoutWriteDiagnostics.inspectSession(
          payload: session,
          ownerId: 'owner_1',
          sessionId: 'session_1',
        ),
        isEmpty,
      );
      expect(
        FirestoreWorkoutWriteDiagnostics.inspectRep(
          payload: rep,
          ownerId: 'owner_1',
          sessionId: 'session_1',
          repId: 'rep_0001',
        ),
        isEmpty,
      );
    });

    test('reports session accepted-count and score violations', () {
      final session = _validSessionPayload()
        ..['totalReps'] = 1
        ..['validReps'] = 1
        ..['lowConfidenceReps'] = 1
        ..['averageScore'] = double.nan;

      final issues = FirestoreWorkoutWriteDiagnostics.inspectSession(
        payload: session,
        ownerId: 'owner_1',
        sessionId: 'session_1',
      );

      expect(issues, contains('session.acceptedCountsExceedTotal'));
      expect(issues, contains('session.averageScore'));
    });

    test('reports rep confidence and duration violations', () {
      final rep = _validRepPayload()
        ..['confidence'] = 0.5
        ..['descentMillis'] = -1;

      final issues = FirestoreWorkoutWriteDiagnostics.inspectRep(
        payload: rep,
        ownerId: 'owner_1',
        sessionId: 'session_1',
        repId: 'rep_0001',
      );

      expect(issues, contains('rep.confidenceCombinedMismatch'));
      expect(issues, contains('rep.descentMillis'));
    });
  });
}

Map<String, dynamic> _validSessionPayload() {
  final startedAt = Timestamp.fromDate(DateTime.utc(2026, 8, 2, 9));
  final endedAt = Timestamp.fromDate(DateTime.utc(2026, 8, 2, 9, 1));
  return <String, dynamic>{
    'id': 'session_1',
    'ownerId': 'owner_1',
    'exerciseType': 'biceps_curl',
    'analysisKind': 'rangeRep',
    'startedAt': startedAt,
    'endedAt': endedAt,
    'durationSeconds': 60,
    'totalReps': 1,
    'validReps': 1,
    'lowConfidenceReps': 0,
    'invalidReps': 0,
    'averageScore': 90.0,
    'bestScore': 90.0,
    'worstScore': 90.0,
    'formWarningCount': 0,
    'holdDurationSeconds': 0.0,
    'bestHoldSeconds': 0.0,
    'holdFormBreakCount': 0,
    'createdAt': startedAt,
    'updatedAt': endedAt,
  };
}

Map<String, dynamic> _validRepPayload() {
  final timestamp = Timestamp.fromDate(DateTime.utc(2026, 8, 2, 9, 1));
  return <String, dynamic>{
    'id': 'rep_0001',
    'ownerId': 'owner_1',
    'sessionId': 'session_1',
    'exerciseType': 'biceps_curl',
    'analysisKind': 'rangeRep',
    'repIndex': 1,
    'score': 90.0,
    'isValid': true,
    'validationStatus': 'valid',
    'invalidReason': null,
    'validationReasons': const <String>[],
    'endedAt': timestamp,
    'durationSeconds': 2.0,
    'minPrimaryMetric': 70.0,
    'worstFormMetric': 10.0,
    'descentMillis': 1000,
    'ascentMillis': 1000,
    'hadFormViolation': false,
    'hadCoverageDrop': false,
    'switchedSideDuringRep': false,
    'completedPhaseSequence': true,
    'selectedSide': 'left',
    'measurementConfidence': <String, Object?>{
      'landmarkLikelihood': 0.99,
      'signalAvailability': 1.0,
      'geometryPlausibility': 1.0,
      'temporalContinuity': 0.8,
      'combined': 0.95,
      'issues': const <String>['temporal_discontinuity'],
    },
    'confidence': 0.95,
    'primaryRom': 90.0,
    'eccentricMillis': 1000,
    'concentricMillis': 1000,
    'tempoMeasurementStatus': 'eligible',
    'tempoMeasurementIssues': const <String>[],
    'tempoQuality': 'target',
    'tempoSeverity': 'none',
    'tempoReasons': const <String>[],
    'tempoIncludedInScore': true,
    'tempoTotalMillis': 2000,
    'techniqueObservations': const <Map<String, Object?>>[],
    'coverageQuality': 1.0,
    'feedback': 'Rep completed!',
    'createdAt': timestamp,
  };
}
