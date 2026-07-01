class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.progress,
    required this.requirementText,
  });

  final String id;
  final String title;
  final String description;
  final bool isUnlocked;
  final double progress;
  final String requirementText;

  double get normalizedProgress => progress.clamp(0, 1).toDouble();
}
