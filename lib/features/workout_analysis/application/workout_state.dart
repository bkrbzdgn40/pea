enum WorkoutStatus { idle, analyzing, paused, completed }

class WorkoutState {
  const WorkoutState({
    this.status = WorkoutStatus.idle,
    this.repCount = 0,
    this.feedbackMessage,
  });

  final WorkoutStatus status;
  final int repCount;
  final String? feedbackMessage;
}
