import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/session_achievement_facts_builder.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/mappers/workout_session_firestore_mapper.dart';

void main() {
  const mapper = WorkoutSessionFirestoreMapper();

  test('pre-evidence legacy session still opens without inventing trust', () {
    final session = mapper.fromDocument(
      _legacySessionDocument(),
      fallbackId: 'fallback-id',
      fallbackOwnerId: 'fallback-owner',
    );

    expect(session.id, 'legacy-session');
    expect(session.durationSec, 90);
    expect(session.totalHoldSeconds, 0);
    expect(session.measurementQuality, SessionMeasurementQuality.unknown);
    expect(session.timezoneOffset, isNull);

    final facts = const SessionAchievementFactsBuilder().build([session]);
    expect(facts.reliableSessionIds, isEmpty);
    expect(facts.reliableExerciseTypes, isEmpty);
  });

  test(
    'mid-rollout trusted session without timezone stays achievement-compatible',
    () {
      final data = _legacySessionDocument()
        ..['preparationOutcome'] = 'passed'
        ..['measurementQuality'] = 'moderate'
        ..['averageMeasurementConfidence'] = 0.86
        ..['measurementSampleCount'] = 8;

      final session = mapper.fromDocument(
        data,
        fallbackId: 'fallback-id',
        fallbackOwnerId: 'fallback-owner',
      );
      final facts = const SessionAchievementFactsBuilder().build([session]);

      expect(session.timezoneOffset, isNull);
      expect(session.measurementQuality, SessionMeasurementQuality.moderate);
      expect(facts.reliableSessionIds, contains('legacy-session'));
      expect(facts.reliableExerciseTypes, isNotEmpty);
    },
  );
}

Map<String, dynamic> _legacySessionDocument() {
  final startedAt = DateTime.utc(2026, 7, 20, 10);
  final endedAt = startedAt.add(const Duration(seconds: 90));
  return <String, dynamic>{
    'id': 'legacy-session',
    'ownerId': 'owner-1',
    'exerciseType': 'push_up',
    'analysisKind': 'rangeRep',
    'startedAt': Timestamp.fromDate(startedAt),
    'endedAt': Timestamp.fromDate(endedAt),
    // Pre-migration field names intentionally remain here.
    'durationSec': 90,
    'totalReps': 8,
    'validReps': 8,
    'invalidReps': 0,
    'averageScore': 82.0,
    'bestScore': 90.0,
    'worstScore': 74.0,
    'formWarningCount': 1,
    'totalHoldSeconds': 0.0,
    'bestHoldSeconds': 0.0,
    'formBreakCount': 0,
    'createdAt': Timestamp.fromDate(startedAt),
    'updatedAt': Timestamp.fromDate(endedAt),
  };
}
