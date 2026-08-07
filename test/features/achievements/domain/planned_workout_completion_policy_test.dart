import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/planned_workout_completion_policy.dart';

void main() {
  const policy = PlannedWorkoutCompletionPolicy();

  test('requires every planned set and persisted set sessions', () {
    expect(
      policy.qualifies(
        totalSets: 4,
        completedSets: 4,
        allSetSessionsPersisted: true,
      ),
      isTrue,
    );
    expect(
      policy.qualifies(
        totalSets: 4,
        completedSets: 3,
        allSetSessionsPersisted: true,
      ),
      isFalse,
    );
    expect(
      policy.qualifies(
        totalSets: 4,
        completedSets: 4,
        allSetSessionsPersisted: false,
      ),
      isFalse,
    );
    expect(
      policy.qualifies(
        totalSets: 0,
        completedSets: 0,
        allSetSessionsPersisted: true,
      ),
      isFalse,
    );
  });
}
