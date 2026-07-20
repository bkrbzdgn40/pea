enum ExerciseType {
  squat(id: 'squat', title: 'Squat'),
  plank(id: 'plank', title: 'Plank'),
  hollowHold(id: 'hollow_hold', title: 'Hollow Hold'),
  lunge(id: 'lunge', title: 'Stationary Lunge'),
  pushUp(id: 'push_up', title: 'Push-up'),
  sitUp(id: 'sit_up', title: 'Sit-up'),
  bicepsCurl(id: 'biceps_curl', title: 'Biceps Curl'),
  lyingLegRaise(id: 'lying_leg_raise', title: 'Lying Leg Raise'),
  tricepsDip(id: 'triceps_dip', title: 'Triceps Dip'),
  romanianDeadlift(id: 'romanian_deadlift', title: 'Romanian Deadlift'),
  lateralRaise(id: 'lateral_raise', title: 'Lateral Raise'),
  shoulderPress(id: 'shoulder_press', title: 'Shoulder Press');

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
