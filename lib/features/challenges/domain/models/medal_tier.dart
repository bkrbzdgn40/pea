/// Highest medal reached inside one challenge period.
enum MedalTier {
  none,
  bronze,
  silver,
  gold;

  String get storageValue => switch (this) {
    MedalTier.none => 'none',
    MedalTier.bronze => 'bronze',
    MedalTier.silver => 'silver',
    MedalTier.gold => 'gold',
  };

  int get rank => switch (this) {
    MedalTier.none => 0,
    MedalTier.bronze => 1,
    MedalTier.silver => 2,
    MedalTier.gold => 3,
  };

  static MedalTier? tryParse(String? value) {
    return switch (value) {
      'none' => MedalTier.none,
      'bronze' => MedalTier.bronze,
      'silver' => MedalTier.silver,
      'gold' => MedalTier.gold,
      _ => null,
    };
  }
}
