/// Persistent reward categories stored in the shared reward ledger.
enum RewardKind {
  challengeMedal,
  achievement;

  String get storageValue => switch (this) {
    RewardKind.challengeMedal => 'challengeMedal',
    RewardKind.achievement => 'achievement',
  };

  static RewardKind? tryParse(String? value) {
    return switch (value) {
      'challengeMedal' => RewardKind.challengeMedal,
      'achievement' => RewardKind.achievement,
      _ => null,
    };
  }
}
