enum ExerciseType {
  squat(id: 'squat', title: 'Squat'),
  plank(id: 'plank', title: 'Plank'),
  hollowHold(id: 'hollow_hold', title: 'Hollow Hold'),
  lunge(id: 'lunge', title: 'Stationary Lunge'),
  pushUp(id: 'push_up', title: 'Push-up'),
  sitUp(id: 'sit_up', title: 'Sit-up'),
  bicepsCurl(id: 'biceps_curl', title: 'Biceps Curl'),
  lyingLegRaise(id: 'lying_leg_raise', title: 'Lying Leg Raise'),
  tricepsDip(id: 'triceps_dip', title: 'Bench Dip'),
  romanianDeadlift(id: 'romanian_deadlift', title: 'Romanian Deadlift'),
  lateralRaise(id: 'lateral_raise', title: 'Lateral Raise'),
  shoulderPress(id: 'shoulder_press', title: 'Shoulder Press'),
  calfRaise(id: 'calf_raise', title: 'Calf Raise'),
  frontRaise(id: 'front_raise', title: 'Front Raise'),
  gluteBridge(id: 'glute_bridge', title: 'Glute Bridge'),
  wallSit(id: 'wall_sit', title: 'Wall Sit'),
  sidePlank(id: 'side_plank', title: 'Side Plank'),
  jumpingJack(id: 'jumping_jack', title: 'Jumping Jack');

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
