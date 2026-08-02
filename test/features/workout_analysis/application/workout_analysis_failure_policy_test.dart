import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_analysis_failure_policy.dart';

void main() {
  test('ordinary failures recover until the consecutive threshold', () {
    final policy = WorkoutAnalysisFailurePolicy(consecutiveFailureThreshold: 3);

    final first = policy.recordFailure(
      WorkoutAnalysisFailureKind.processingException,
    );
    final second = policy.recordFailure(
      WorkoutAnalysisFailureKind.processingException,
    );
    final third = policy.recordFailure(
      WorkoutAnalysisFailureKind.processingException,
    );

    expect(first.disposition, WorkoutAnalysisFailureDisposition.recovering);
    expect(second.disposition, WorkoutAnalysisFailureDisposition.recovering);
    expect(third.disposition, WorkoutAnalysisFailureDisposition.blocked);
    expect(policy.isBlocked, isTrue);
    expect(policy.consecutiveFailureCount, 3);
  });

  test('timeout blocks immediately and success clears transient failures', () {
    final policy = WorkoutAnalysisFailurePolicy();

    policy.recordFailure(WorkoutAnalysisFailureKind.processingException);
    expect(policy.recordSuccess(), isTrue);
    expect(policy.isBlocked, isFalse);
    expect(policy.consecutiveFailureCount, 0);
    expect(policy.recordSuccess(), isFalse);

    final timeout = policy.recordFailure(
      WorkoutAnalysisFailureKind.poseDetectionTimeout,
    );
    expect(timeout.disposition, WorkoutAnalysisFailureDisposition.blocked);
    expect(timeout.consecutiveFailureCount, 1);
    expect(policy.isBlocked, isTrue);
  });

  test('threshold must be positive', () {
    expect(
      () => WorkoutAnalysisFailurePolicy(consecutiveFailureThreshold: 0),
      throwsArgumentError,
    );
  });
}
