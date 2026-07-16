enum ExerciseType {
  squat(id: 'squat', title: 'Squat'),
  plank(id: 'plank', title: 'Plank'),
  lunge(id: 'lunge', title: 'Lunge'),
  pushUp(id: 'push_up', title: 'Push-up'),
  sitUp(id: 'sit_up', title: 'Sit-up'),
  bicepsCurl(id: 'biceps_curl', title: 'Biceps Curl');

  const ExerciseType({required this.id, required this.title});

  final String id;
  final String title;

  static ExerciseType? fromIdOrNull(String id) {
    for (final exercise in ExerciseType.values) {
      if (exercise.id == id) {
        return exercise;
      }
    }

    return null;
  }

  static ExerciseType fromId(String id) {
    final exercise = fromIdOrNull(id);
    if (exercise != null) {
      return exercise;
    }

    throw ArgumentError.value(id, 'id', 'Unknown exercise id');
  }
}
