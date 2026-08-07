import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  test('rejects fractional repetition contributions', () {
    expect(() => _contribution(value: 10.5), throwsArgumentError);
  });

  test('rejects a session id that cannot be a Firestore document id', () {
    expect(
      () => _contribution(sessionId: 'sessions/session-1'),
      throwsArgumentError,
    );
  });

  test('keeps the captured local day stable', () {
    final contribution = _contribution();

    expect(contribution.dailyWindow.key, '2026-08-07');
    expect(contribution.dailyWindow.timezoneOffsetMinutes, 180);
  });
}

ChallengeContribution _contribution({
  String sessionId = 'session-1',
  double value = 10,
}) {
  return ChallengeContribution(
    sessionId: sessionId,
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    evidenceQuality: ChallengeEvidenceQuality.high,
    value: value,
    endedAt: DateTime.utc(2026, 8, 6, 21),
    timezoneOffset: const Duration(hours: 3),
  );
}
