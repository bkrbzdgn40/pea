import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/runtime_achievement_facts_builder.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event_record.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution_record.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('RuntimeAchievementFactsBuilder', () {
    const builder = RuntimeAchievementFactsBuilder();

    test('counts controlled tempo only while its trusted session exists', () {
      final event = AchievementEventRecord(
        ownerId: 'user-1',
        event: AchievementEvent.controlledTempoSession(
          sessionId: 'session-1',
          occurredAt: DateTime.utc(2026, 8, 7, 10),
        ),
        localDate: '2026-08-07',
        timezoneOffset: Duration.zero,
        createdAt: DateTime.utc(2026, 8, 7, 10, 1),
      );

      final withoutSession = builder.build(
        contributions: const <ChallengeContributionRecord>[],
        events: <AchievementEventRecord>[event],
        weeklyMedals: const [],
      );
      expect(withoutSession.controlledTempoSessionIds, isEmpty);

      final contribution = ChallengeContributionRecord(
        ownerId: 'user-1',
        contribution: ChallengeContribution(
          sessionId: 'session-1',
          challengeId: 'push_up_volume',
          catalogVersion: 1,
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          evidenceQuality: ChallengeEvidenceQuality.high,
          value: 5,
          endedAt: DateTime.utc(2026, 8, 7, 10),
          timezoneOffset: Duration.zero,
        ),
        createdAt: DateTime.utc(2026, 8, 7, 10, 1),
        updatedAt: DateTime.utc(2026, 8, 7, 10, 1),
      );
      final withSession = builder.build(
        contributions: <ChallengeContributionRecord>[contribution],
        events: <AchievementEventRecord>[event],
        weeklyMedals: const [],
      );
      expect(withSession.controlledTempoSessionIds, <String>{'session-1'});
    });
  });
}
