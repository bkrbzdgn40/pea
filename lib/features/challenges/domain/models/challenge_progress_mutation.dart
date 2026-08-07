/// Result of an idempotent contribution upsert.
enum ChallengeContributionWriteStatus { created, unchanged, replaced }

class ChallengeContributionWriteResult {
  const ChallengeContributionWriteResult({
    required this.status,
    required this.affectedLocalDates,
  });

  final ChallengeContributionWriteStatus status;
  final Set<String> affectedLocalDates;
}
