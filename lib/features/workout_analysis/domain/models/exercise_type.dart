enum ExerciseType {
  squat(id: 'squat', title: 'Squat'),
  plank(id: 'plank', title: 'Plank'),
  lunge(id: 'lunge', title: 'Lunge'),
  pushUp(id: 'push_up', title: 'Push-up'),
  sitUp(id: 'sit_up', title: 'Sit-up');

  const ExerciseType({required this.id, required this.title});

  final String id;
  final String title;

  static ExerciseType fromId(String id) {
    return ExerciseType.values.firstWhere(
      (exercise) => exercise.id == id,
      orElse: () => ExerciseType.squat,
    );
  }
}
