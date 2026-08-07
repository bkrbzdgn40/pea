import 'challenge_contribution.dart';

/// Persisted contribution metadata used for idempotent reconciliation.
class ChallengeContributionRecord {
  ChallengeContributionRecord({
    required this.ownerId,
    required this.contribution,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : createdAtUtc = createdAt.toUtc(),
       updatedAtUtc = updatedAt.toUtc() {
    if (ownerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Must not be empty.');
    }
    if (updatedAtUtc.isBefore(createdAtUtc)) {
      throw ArgumentError.value(
        updatedAt,
        'updatedAt',
        'Must not be before createdAt.',
      );
    }
  }

  final String ownerId;
  final ChallengeContribution contribution;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String get id => contribution.sessionId;
  String get localDate => contribution.dailyWindow.key;
}
