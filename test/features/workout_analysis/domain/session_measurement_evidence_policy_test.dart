import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/session_measurement_evidence_policy.dart';

void main() {
  const policy = SessionMeasurementEvidencePolicy();

  group('SessionMeasurementEvidencePolicy', () {
    test('classifies multiple reliable passed samples as high quality', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.96,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.92,
          ),
        ],
      );

      expect(evidence.preparationOutcome, PreparationOutcome.passed);
      expect(evidence.measurementQuality, SessionMeasurementQuality.high);
      expect(evidence.measurementSampleCount, 2);
      expect(evidence.averageMeasurementConfidence, closeTo(0.94, 0.0001));
    });

    test('classifies mixed accepted samples as moderate quality', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.86,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.84,
          ),
          WorkoutRep(
            repIndex: 3,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.82,
          ),
          WorkoutRep(
            repIndex: 4,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'lowConfidence',
            confidence: 0.80,
          ),
        ],
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.moderate);
      expect(evidence.measurementSampleCount, 4);
      expect(evidence.averageMeasurementConfidence, closeTo(0.83, 0.0001));
    });

    test('manual preparation override caps otherwise strong evidence', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.overridden,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.98,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.97,
          ),
        ],
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.limited);
      expect(evidence.averageMeasurementConfidence, closeTo(0.975, 0.0001));
    });

    test('missing preparation proof caps otherwise strong evidence', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.legacyUnknown,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.98,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.97,
          ),
        ],
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.limited);
    });

    test('one known sample is insufficient for a session-level claim', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.99,
          ),
        ],
      );

      expect(
        evidence.measurementQuality,
        SessionMeasurementQuality.insufficient,
      );
      expect(evidence.measurementSampleCount, 1);
    });

    test('missing confidence remains unknown instead of inventing quality', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
          ),
        ],
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.unknown);
      expect(evidence.averageMeasurementConfidence, isNull);
      expect(evidence.measurementSampleCount, 0);
    });

    test('too many low-confidence outcomes remain limited', () {
      final evidence = policy.evaluate(
        preparationOutcome: PreparationOutcome.passed,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            confidence: 0.91,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'lowConfidence',
            confidence: 0.89,
          ),
          WorkoutRep(
            repIndex: 3,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'lowConfidence',
            confidence: 0.88,
          ),
        ],
      );

      expect(evidence.measurementQuality, SessionMeasurementQuality.limited);
      expect(evidence.measurementSampleCount, 3);
    });
  });
}
