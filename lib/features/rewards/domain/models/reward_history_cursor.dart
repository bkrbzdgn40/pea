class RewardHistoryCursor {
  RewardHistoryCursor({required DateTime sortAt, required this.rewardId})
    : sortAtUtc = sortAt.toUtc() {
    if (rewardId.isEmpty || rewardId.contains('/')) {
      throw ArgumentError.value(
        rewardId,
        'rewardId',
        'Must be a non-empty Firestore document id.',
      );
    }
  }

  final DateTime sortAtUtc;
  final String rewardId;
}
