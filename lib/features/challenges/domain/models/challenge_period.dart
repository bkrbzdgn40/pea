/// Calendar window in which challenge progress is accumulated.
enum ChallengePeriod {
  daily,
  weekly,
  monthly;

  String get storageValue => switch (this) {
    ChallengePeriod.daily => 'daily',
    ChallengePeriod.weekly => 'weekly',
    ChallengePeriod.monthly => 'monthly',
  };

  static ChallengePeriod? tryParse(String? value) {
    return switch (value) {
      'daily' => ChallengePeriod.daily,
      'weekly' => ChallengePeriod.weekly,
      'monthly' => ChallengePeriod.monthly,
      _ => null,
    };
  }
}
