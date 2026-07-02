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
    this.isAnalysisAvailable = false,
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
  final bool isAnalysisAvailable;
}
