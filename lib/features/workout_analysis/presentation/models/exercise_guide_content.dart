class ExerciseGuideContent {
  const ExerciseGuideContent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.difficulty,
    required this.tips,
    required this.commonMistakes,
    this.isAnalysisAvailable = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String difficulty;
  final List<String> tips;
  final List<String> commonMistakes;
  final bool isAnalysisAvailable;
}
