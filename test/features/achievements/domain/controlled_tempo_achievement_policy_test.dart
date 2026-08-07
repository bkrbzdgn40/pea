import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/controlled_tempo_achievement_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  const policy = ControlledTempoAchievementPolicy();

  test('unlocks at five eligible reps with at least eighty percent target', () {
    final session = _session();
    final reps = <WorkoutRep>[
      _rep(1, 'target'),
      _rep(2, 'target'),
      _rep(3, 'target'),
      _rep(4, 'target'),
      _rep(5, 'fast'),
    ];

    expect(policy.qualifies(session: session, reps: reps), isTrue);
  });

  test('limited sessions and unsupported exercises never qualify', () {
    expect(
      policy.qualifies(
        session: _session(quality: SessionMeasurementQuality.limited),
        reps: List.generate(5, (index) => _rep(index + 1, 'target')),
      ),
      isFalse,
    );
    expect(
      policy.qualifies(
        session: _session(exerciseType: 'calf_raise'),
        reps: List.generate(
          5,
          (index) => _rep(index + 1, 'target', exerciseType: 'calf_raise'),
        ),
      ),
      isFalse,
    );
  });

  test('ineligible and invalid reps do not enter the denominator', () {
    final reps = <WorkoutRep>[
      _rep(1, 'target'),
      _rep(2, 'target'),
      _rep(3, 'target'),
      _rep(4, 'target'),
      _rep(5, 'target'),
      _rep(6, 'fast', validationStatus: 'invalid'),
      _rep(7, 'fast', tempoMeasurementStatus: 'unavailable'),
    ];

    expect(policy.qualifies(session: _session(), reps: reps), isTrue);
  });
}

WorkoutSession _session({
  String exerciseType = 'squat',
  SessionMeasurementQuality quality = SessionMeasurementQuality.high,
}) {
  return WorkoutSession(
    id: 'session-1',
    ownerId: 'owner',
    exerciseType: exerciseType,
    startedAt: DateTime.utc(2026, 8, 7, 8),
    endedAt: DateTime.utc(2026, 8, 7, 8, 1),
    durationSec: 60,
    totalReps: 5,
    validReps: 5,
    averageScore: 0,
    bestScore: 0,
    formWarningCount: 0,
    preparationOutcome:
        quality == SessionMeasurementQuality.high ||
            quality == SessionMeasurementQuality.moderate
        ? PreparationOutcome.passed
        : PreparationOutcome.overridden,
    measurementQuality: quality,
    averageMeasurementConfidence: 0.9,
    measurementSampleCount: 5,
  );
}

WorkoutRep _rep(
  int index,
  String tempoQuality, {
  String exerciseType = 'squat',
  String validationStatus = 'valid',
  String tempoMeasurementStatus = 'eligible',
}) {
  return WorkoutRep(
    repIndex: index,
    exerciseType: exerciseType,
    analysisKind: 'rangeRep',
    validationStatus: validationStatus,
    tempoMeasurementStatus: tempoMeasurementStatus,
    tempoQuality: tempoQuality,
  );
}
