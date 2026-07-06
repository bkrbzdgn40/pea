enum ExerciseDifficulty { beginner, intermediate, advanced }

extension ExerciseDifficultyLabel on ExerciseDifficulty {
  String get label {
    return switch (this) {
      ExerciseDifficulty.beginner => 'Başlangıç',
      ExerciseDifficulty.intermediate => 'Orta',
      ExerciseDifficulty.advanced => 'İleri',
    };
  }
}

/// Local guide entry for rich presentation copy; analysis policy lives in ExerciseCatalog.
class ExerciseGuideContent {
  const ExerciseGuideContent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.purpose,
    required this.difficulty,
    required this.setupSteps,
    required this.tips,
    required this.commonMistakes,
    required this.youtubeUrl,
    required this.youtubeSourceLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String purpose;
  final ExerciseDifficulty difficulty;
  final List<String> setupSteps;
  final List<String> tips;
  final List<String> commonMistakes;
  final String youtubeUrl;
  final String youtubeSourceLabel;
}
