class WorkoutGoal {
  const WorkoutGoal({
    required this.id,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.description,
    required this.isCompleted,
  });

  final String id;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;
  final String description;
  final bool isCompleted;

  double get progress {
    if (targetValue <= 0) return 0;

    return (currentValue / targetValue).clamp(0, 1).toDouble();
  }
}
