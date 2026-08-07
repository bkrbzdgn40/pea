class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.isUnlocked,
    required this.progress,
    required this.requirementText,
    this.current = 0,
    this.target = 1,
    this.unlockedAtUtc,
    this.isSecret = false,
  });

  final String id;
  final String title;
  final String description;
  final bool isUnlocked;
  final double progress;
  final String requirementText;
  final int current;
  final int target;
  final DateTime? unlockedAtUtc;
  final bool isSecret;

  double get normalizedProgress => progress.clamp(0, 1).toDouble();
  int get remaining => (target - current).clamp(0, target).toInt();
}
