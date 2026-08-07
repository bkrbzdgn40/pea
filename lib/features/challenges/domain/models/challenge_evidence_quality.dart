/// Trusted session evidence levels accepted by the challenge subsystem.
enum ChallengeEvidenceQuality {
  high,
  moderate;

  String get storageValue => switch (this) {
    ChallengeEvidenceQuality.high => 'high',
    ChallengeEvidenceQuality.moderate => 'moderate',
  };

  static ChallengeEvidenceQuality? tryParse(String? value) {
    return switch (value) {
      'high' => ChallengeEvidenceQuality.high,
      'moderate' => ChallengeEvidenceQuality.moderate,
      _ => null,
    };
  }
}
