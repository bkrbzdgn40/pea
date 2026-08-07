class PlannedWorkoutCompletionPolicy {
  const PlannedWorkoutCompletionPolicy();

  bool qualifies({
    required int totalSets,
    required int completedSets,
    required bool allSetSessionsPersisted,
  }) {
    return totalSets > 0 &&
        completedSets == totalSets &&
        allSetSessionsPersisted;
  }
}
