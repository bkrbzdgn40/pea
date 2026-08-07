/// The trusted quantity accumulated by one exercise challenge.
enum ChallengeMetric {
  validRepetitions,
  trustedHoldSeconds;

  String get storageValue => switch (this) {
    ChallengeMetric.validRepetitions => 'validRepetitions',
    ChallengeMetric.trustedHoldSeconds => 'trustedHoldSeconds',
  };

  String get requiredAnalysisKind => switch (this) {
    ChallengeMetric.validRepetitions => 'rangeRep',
    ChallengeMetric.trustedHoldSeconds => 'hold',
  };

  static ChallengeMetric? tryParse(String? value) {
    return switch (value) {
      'validRepetitions' => ChallengeMetric.validRepetitions,
      'trustedHoldSeconds' => ChallengeMetric.trustedHoldSeconds,
      _ => null,
    };
  }
}
