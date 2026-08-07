import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/session_achievement_facts_builder.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_body_region.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  const builder = SessionAchievementFactsBuilder();

  test(
    'only high and moderate sessions with meaningful evidence are reliable',
    () {
      final facts = builder.build([
        _session(
          id: 'high-squat',
          validReps: 8,
          totalReps: 8,
          quality: SessionMeasurementQuality.high,
        ),
        _session(
          id: 'limited',
          validReps: 50,
          totalReps: 50,
          quality: SessionMeasurementQuality.limited,
        ),
        _session(id: 'legacy', validReps: 50, totalReps: 50),
      ]);

      expect(facts.reliableSessionIds, {'high-squat'});
      expect(facts.reliableBodyRegions, {AchievementBodyRegion.lowerBody});
    },
  );

  test('hold sessions need at least five reliable seconds', () {
    final facts = builder.build([
      _session(
        id: 'short-plank',
        exerciseType: 'plank',
        analysisKind: 'hold',
        totalHoldSeconds: 4,
        quality: SessionMeasurementQuality.moderate,
      ),
      _session(
        id: 'plank',
        exerciseType: 'plank',
        analysisKind: 'hold',
        totalHoldSeconds: 20,
        quality: SessionMeasurementQuality.moderate,
      ),
    ]);

    expect(facts.reliableSessionIds, {'plank'});
    expect(facts.reliableBodyRegions, {AchievementBodyRegion.core});
  });
}

WorkoutSession _session({
  required String id,
  String exerciseType = 'squat',
  String analysisKind = 'rangeRep',
  int totalReps = 0,
  int validReps = 0,
  double totalHoldSeconds = 0,
  SessionMeasurementQuality quality = SessionMeasurementQuality.unknown,
}) {
  final hasKnownEvidence = quality != SessionMeasurementQuality.unknown;
  return WorkoutSession(
    id: id,
    ownerId: 'owner',
    exerciseType: exerciseType,
    analysisKind: analysisKind,
    startedAt: DateTime(2026, 8, 1, 10),
    endedAt: DateTime(2026, 8, 1, 10, 1),
    durationSec: 60,
    totalReps: totalReps,
    validReps: validReps,
    averageScore: 0,
    bestScore: 0,
    formWarningCount: 0,
    totalHoldSeconds: totalHoldSeconds,
    preparationOutcome: hasKnownEvidence
        ? PreparationOutcome.passed
        : PreparationOutcome.legacyUnknown,
    measurementQuality: quality,
    averageMeasurementConfidence: hasKnownEvidence ? 0.9 : null,
    measurementSampleCount: hasKnownEvidence ? 5 : 0,
  );
}
