import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
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
        measurementConfidence: MeasurementConfidenceBreakdown(
          landmarkLikelihood: 0.98,
          signalAvailability: 0.96,
          geometryPlausibility: 1.0,
          temporalContinuity: 0.84,
          combined: 0.91,
          issues: const <MeasurementConfidenceIssue>[
            MeasurementConfidenceIssue.temporalDiscontinuity,
          ],
        ),
        primaryRom: 62.0,
        eccentricMillis: 800,
        concentricMillis: 700,
        tempoMeasurementStatus: 'eligible',
        tempoQuality: 'tooSlow',
        tempoSeverity: 'mild',
        tempoReasons: const <String>['totalTooSlow'],
        tempoIncludedInScore: true,
        tempoTotalMillis: 1500,
        techniqueObservations: const <Map<String, Object?>>[
          <String, Object?>{
            'type': 'torsoSwing',
            'code': 'biceps_torso_swing_observed',
            'severity': 'info',
          },
        ],
        coverageQuality: 0.94,
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
      expect(document['confidence'], 0.91);
      expect(document['measurementConfidence'], <String, Object?>{
        'landmarkLikelihood': 0.98,
        'signalAvailability': 0.96,
        'geometryPlausibility': 1.0,
        'temporalContinuity': 0.84,
        'combined': 0.91,
        'issues': <String>['temporal_discontinuity'],
      });
      expect(document['primaryRom'], 62.0);
      expect(document['eccentricMillis'], 800);
      expect(document['concentricMillis'], 700);
      expect(document['tempoMeasurementStatus'], 'eligible');
      expect(document['tempoQuality'], 'tooSlow');
      expect(document['tempoSeverity'], 'mild');
      expect(document['tempoReasons'], <String>['totalTooSlow']);
      expect(document['tempoIncludedInScore'], isTrue);
      expect(document['tempoTotalMillis'], 1500);
      expect(document['techniqueObservations'], hasLength(1));
      expect(document['coverageQuality'], 0.94);
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
        'measurementConfidence': <String, Object?>{
          'landmarkLikelihood': 0.96,
          'signalAvailability': 1.0,
          'geometryPlausibility': 1.0,
          'temporalContinuity': 0.72,
          'combined': 0.88,
          'issues': const <String>['temporal_discontinuity'],
        },
        'confidence': 0.88,
        'primaryRom': 70.0,
        'eccentricMillis': 600,
        'concentricMillis': 500,
        'tempoMeasurementStatus': 'eligible',
        'tempoMeasurementIssues': const <String>[],
        'tempoQuality': 'target',
        'tempoSeverity': 'none',
        'tempoReasons': const <String>[],
        'tempoIncludedInScore': true,
        'tempoTotalMillis': 1100,
        'techniqueObservations': const <Map<String, Object?>>[
          <String, Object?>{
            'type': 'torsoSwing',
            'code': 'biceps_torso_swing_observed',
            'severity': 'info',
          },
        ],
        'coverageQuality': 0.9,
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
      expect(rep.selectedSide, 'right');
      expect(rep.confidence, 0.88);
      expect(rep.measurementConfidence?.landmarkLikelihood, 0.96);
      expect(rep.measurementConfidence?.signalAvailability, 1.0);
      expect(rep.measurementConfidence?.geometryPlausibility, 1.0);
      expect(rep.measurementConfidence?.temporalContinuity, 0.72);
      expect(
        rep.measurementConfidence?.issues,
        const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.temporalDiscontinuity,
        ],
      );
      expect(rep.primaryRom, 70.0);
      expect(rep.eccentricMillis, 600);
      expect(rep.concentricMillis, 500);
      expect(rep.tempoMeasurementStatus, 'eligible');
      expect(rep.tempoQuality, 'target');
      expect(rep.tempoIncludedInScore, isTrue);
      expect(rep.tempoTotalMillis, 1100);
      expect(rep.observedDuration, const Duration(milliseconds: 1100));
      expect(rep.techniqueObservations, hasLength(1));
      expect(rep.coverageQuality, 0.9);
      expect(rep.recordedAt?.toUtc(), DateTime.utc(2026, 1, 1, 12, 0, 3));
    });

    test('opens legacy scalar-only confidence with a typed fallback', () {
      final rep = mapper.fromDocument(<String, dynamic>{
        'exerciseType': 'squat',
        'analysisKind': 'rangeRep',
        'repIndex': 4,
        'isValid': true,
        'confidence': 0.73,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 0, 8)),
      });

      expect(rep.measurementConfidence, isNull);
      expect(rep.confidence, 0.73);
      expect(rep.effectiveMeasurementConfidence?.combined, 0.73);
      expect(
        rep.effectiveMeasurementConfidence?.issues,
        const <MeasurementConfidenceIssue>[
          MeasurementConfidenceIssue.legacyScalarOnly,
        ],
      );
    });

    test('native breakdown remains the source of truth over legacy scalar', () {
      final rep = mapper.fromDocument(<String, dynamic>{
        'exerciseType': 'squat',
        'analysisKind': 'rangeRep',
        'repIndex': 5,
        'isValid': true,
        'measurementConfidence': <String, Object?>{
          'landmarkLikelihood': 0.9,
          'signalAvailability': 0.8,
          'geometryPlausibility': 1.0,
          'temporalContinuity': 0.7,
          'combined': 0.81,
          'issues': const <String>[],
        },
        'confidence': 0.99,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 0, 9)),
      });

      expect(rep.confidence, 0.81);
      expect(rep.measurementConfidence?.combined, 0.81);
    });

    test(
      'treats false isValid without invalid reasons as unknown and keeps nullables safe',
      () {
        final rep = mapper.fromDocument(<String, dynamic>{
          'id': 'rep_0003',
          'ownerId': 'owner_1',
          'sessionId': 'session_1',
          'exerciseType': 'squat',
          'analysisKind': 'rangeRep',
          'repIndex': 3,
          'isValid': false,
          'score': null,
          'durationSeconds': null,
          'validationReasons': const <String>[],
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 12, 0, 6)),
        });

        expect(rep.validationStatus, 'unknown');
        expect(rep.isValidationUnknown, isTrue);
        expect(rep.score, isNull);
        expect(rep.observedDuration, isNull);
      },
    );
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
