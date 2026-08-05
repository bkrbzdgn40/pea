import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/mappers/workout_session_firestore_mapper.dart';

void main() {
  group('WorkoutSessionFirestoreMapper', () {
    const mapper = WorkoutSessionFirestoreMapper();

    test('serializes summary fields without inlining reps', () {
      final session = _sessionWithReps();

      final document = mapper.toDocument(session);

      expect(document['id'], session.id);
      expect(document['ownerId'], session.ownerId);
      expect(document['durationSeconds'], session.durationSec);
      expect(document['validReps'], 1);
      expect(document['lowConfidenceReps'], 1);
      expect(document['invalidReps'], 1);
      expect(document['worstScore'], 77.0);
      expect(document['holdDurationSeconds'], session.totalHoldSeconds);
      expect(document['bestHoldSeconds'], session.bestHoldSeconds);
      expect(document['holdFormBreakCount'], session.formBreakCount);
      expect(document['preparationOutcome'], 'overridden');
      expect(document['measurementQuality'], 'limited');
      expect(document['averageMeasurementConfidence'], 0.72);
      expect(document['measurementSampleCount'], 2);
      expect(document['startedAt'], isA<Timestamp>());
      expect(document['endedAt'], isA<Timestamp>());
      expect(document.containsKey('reps'), isFalse);
    });

    test('reads both current and legacy summary field names', () {
      final session = mapper.fromDocument(
        <String, dynamic>{
          'id': 'session_1',
          'ownerId': 'owner_1',
          'exerciseType': 'squat',
          'analysisKind': 'rangeRep',
          'startedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12)),
          'endedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 10)),
          'durationSec': 600,
          'totalReps': 8,
          'validReps': 6,
          'lowConfidenceReps': 1,
          'invalidReps': 1,
          'averageScore': 82.5,
          'bestScore': 95.0,
          'worstScore': 70.0,
          'formWarningCount': 2,
          'totalHoldSeconds': 0.0,
          'bestHoldSeconds': 0.0,
          'formBreakCount': 0,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12)),
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 10)),
        },
        fallbackId: 'fallback',
        fallbackOwnerId: 'fallback-owner',
      );

      expect(session.id, 'session_1');
      expect(session.ownerId, 'owner_1');
      expect(session.durationSec, 600);
      expect(session.validReps, 6);
      expect(session.lowConfidenceReps, 1);
      expect(session.invalidReps, 1);
      expect(session.worstScore, 70.0);
      expect(session.totalHoldSeconds, 0.0);
      expect(session.formBreakCount, 0);
      expect(session.reps, isNull);
      expect(session.preparationOutcome, PreparationOutcome.legacyUnknown);
      expect(session.measurementQuality, SessionMeasurementQuality.unknown);
      expect(session.averageMeasurementConfidence, isNull);
      expect(session.measurementSampleCount, 0);
    });

    test('round-trips current measurement evidence fields', () {
      final session = _sessionWithReps();

      final restored = mapper.fromDocument(
        mapper.toDocument(session),
        fallbackId: 'fallback',
        fallbackOwnerId: 'fallback-owner',
      );

      expect(restored.preparationOutcome, PreparationOutcome.overridden);
      expect(restored.measurementQuality, SessionMeasurementQuality.limited);
      expect(restored.averageMeasurementConfidence, 0.72);
      expect(restored.measurementSampleCount, 2);
    });

    test('preserves hollow_hold session identity without schema changes', () {
      final session = WorkoutSession(
        id: 'session_hollow_1',
        ownerId: 'owner_1',
        exerciseType: 'hollow_hold',
        analysisKind: 'hold',
        startedAt: DateTime.utc(2026, 1, 1, 12),
        endedAt: DateTime.utc(2026, 1, 1, 12, 0, 12),
        durationSec: 12,
        totalReps: 0,
        averageScore: 0.0,
        bestScore: 0.0,
        worstScore: 0.0,
        validReps: 0,
        invalidReps: 0,
        formWarningCount: 0,
        totalHoldSeconds: 8.0,
        bestHoldSeconds: 8.0,
        formBreakCount: 1,
        createdAt: DateTime.utc(2026, 1, 1, 12),
        updatedAt: DateTime.utc(2026, 1, 1, 12, 0, 12),
      );

      final document = mapper.toDocument(session);
      final restored = mapper.fromDocument(
        document,
        fallbackId: 'fallback',
        fallbackOwnerId: 'fallback-owner',
      );

      expect(document['exerciseType'], 'hollow_hold');
      expect(document['analysisKind'], 'hold');
      expect(restored.exerciseType, 'hollow_hold');
      expect(restored.analysisKind, 'hold');
      expect(restored.bestHoldSeconds, 8.0);
      expect(restored.formBreakCount, 1);
    });
  });
}

WorkoutSession _sessionWithReps() {
  return WorkoutSession(
    id: 'session_1',
    ownerId: 'owner_1',
    exerciseType: 'squat',
    analysisKind: 'rangeRep',
    startedAt: DateTime.utc(2026, 1, 1, 12),
    endedAt: DateTime.utc(2026, 1, 1, 12, 10),
    durationSec: 600,
    totalReps: 2,
    averageScore: 83.5,
    bestScore: 90.0,
    worstScore: 77.0,
    validReps: 1,
    lowConfidenceReps: 1,
    invalidReps: 1,
    formWarningCount: 2,
    totalHoldSeconds: 0.0,
    bestHoldSeconds: 0.0,
    formBreakCount: 0,
    preparationOutcome: PreparationOutcome.overridden,
    measurementQuality: SessionMeasurementQuality.limited,
    averageMeasurementConfidence: 0.72,
    measurementSampleCount: 2,
    createdAt: DateTime.utc(2026, 1, 1, 12),
    updatedAt: DateTime.utc(2026, 1, 1, 12, 10),
    reps: const <WorkoutRep>[
      WorkoutRep(
        repIndex: 1,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'valid',
        score: 90.0,
      ),
      WorkoutRep(
        repIndex: 2,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'lowConfidence',
        validationReasons: <String>['excessive descent speed'],
        score: 77.0,
      ),
      WorkoutRep(
        repIndex: 3,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'invalid',
        validationReasons: <String>['insufficient rom'],
        score: 20.0,
      ),
    ],
  );
}
