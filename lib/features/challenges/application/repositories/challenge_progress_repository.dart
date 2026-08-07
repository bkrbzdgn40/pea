import '../../domain/models/activity_day_summary.dart';
import '../../domain/models/challenge_contribution.dart';
import '../../domain/models/challenge_contribution_record.dart';
import '../../domain/models/challenge_progress_mutation.dart';

abstract interface class ChallengeProgressRepository {
  Future<ChallengeContributionWriteResult> upsertContribution({
    required String ownerId,
    required ChallengeContribution contribution,
    required DateTime now,
  });

  Future<bool> removeContribution({
    required String ownerId,
    required String sessionId,
    required DateTime now,
  });

  Future<List<ChallengeContributionRecord>> listContributions({
    required String ownerId,
  });

  Future<ChallengeContributionRecord?> getContribution({
    required String ownerId,
    required String sessionId,
  });

  Future<ActivityDaySummary?> getActivityDay({
    required String ownerId,
    required String localDate,
  });

  Future<List<ActivityDaySummary>> listActivityDays({
    required String ownerId,
    required String startLocalDateInclusive,
    required String endLocalDateExclusive,
  });
}
