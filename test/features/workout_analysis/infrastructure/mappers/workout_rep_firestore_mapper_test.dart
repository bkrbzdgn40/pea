import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/mappers/workout_rep_firestore_mapper.dart';

void main() {
  group('WorkoutRepFirestoreMapper', () {
    const mapper = WorkoutRepFirestoreMapper();

    test('builds a stable rep id from rep index', () {
      const rep = WorkoutRep(
        repIndex: 7,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
      );

      expect(mapper.documentIdFor(rep), 'rep_0007');
    });

    test('serializes rep fields with nullable metrics and feedback', () {
      final session = _session();
      final rep = WorkoutRep(
        repIndex: 2,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        recordedAt: DateTime.utc(2026, 1, 1, 12, 1),
        validationStatus: 'invalid',
        validationReasons: const <String>['insufficient rom'],
        score: 74.0,
        minPrimaryMetric: 98.5,
        worstFormMetric: 53.0,
        descentMillis: 800,
        ascentMillis: 700,
        feedback: 'Daha derine in',
        selectedSideLabel: 'left',
      );

      final document = mapper.toDocument(rep: rep, session: session);

      expect(document['id'], 'rep_0002');
      expect(document['ownerId'], session.ownerId);
      expect(document['sessionId'], session.id);
      expect(document['exerciseType'], rep.exerciseType);
      expect(document['analysisKind'], rep.analysisKind);
      expect(document['repIndex'], 2);
      expect(document['score'], 74.0);
      expect(document['isValid'], isFalse);
      expect(document['validationStatus'], 'invalid');
      expect(document['invalidReason'], 'insufficient rom');
      expect(document['validationReasons'], <String>['insufficient rom']);
      expect(document['endedAt'], isA<Timestamp>());
      expect(document['durationSeconds'], 1.5);
      expect(document['minPrimaryMetric'], 98.5);
      expect(document['worstFormMetric'], 53.0);
      expect(document['selectedSide'], 'left');
      expect(document['feedback'], 'Daha derine in');
    });

    test('deserializes persisted rep data back into the domain model', () {
      final rep = mapper.fromDocument(<String, dynamic>{
        'id': 'rep_0001',
        'ownerId': 'owner_1',
        'sessionId': 'session_1',
        'exerciseType': 'squat',
        'analysisKind': 'rangeRep',
        'repIndex': 1,
        'score': 88.0,
        'isValid': true,
        'validationStatus': 'valid',
        'validationReasons': const <String>[],
        'endedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 0, 3)),
        'minPrimaryMetric': 90.0,
        'worstFormMetric': 42.0,
        'descentMillis': 600,
        'ascentMillis': 500,
        'feedback': 'Guzel kontrol',
        'selectedSide': 'right',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 0, 3)),
      });

      expect(rep.repIndex, 1);
      expect(rep.validationStatus, 'valid');
      expect(rep.validationReasons, isEmpty);
      expect(rep.score, 88.0);
      expect(rep.minPrimaryMetric, 90.0);
      expect(rep.worstFormMetric, 42.0);
      expect(rep.descentMillis, 600);
      expect(rep.ascentMillis, 500);
      expect(rep.feedback, 'Guzel kontrol');
      expect(rep.selectedSideLabel, 'right');
      expect(rep.recordedAt?.toUtc(), DateTime.utc(2026, 1, 1, 12, 0, 3));
    });
  });
}

WorkoutSession _session() {
  return WorkoutSession(
    id: 'session_1',
    ownerId: 'owner_1',
    exerciseType: 'squat',
    analysisKind: 'rangeRep',
    startedAt: DateTime.utc(2026, 1, 1, 12),
    endedAt: DateTime.utc(2026, 1, 1, 12, 10),
    durationSec: 600,
    totalReps: 2,
    averageScore: 82.0,
    bestScore: 90.0,
    worstScore: 74.0,
    validReps: 1,
    invalidReps: 1,
    formWarningCount: 2,
  );
}
