import '../../application/workout_analysis_failure_policy.dart';

enum WorkoutAnalysisHealthStatus { healthy, recovering, blocked }

class WorkoutAnalysisHealthState {
  const WorkoutAnalysisHealthState._({
    required this.status,
    this.failureKind,
    this.consecutiveFailureCount = 0,
  });

  const WorkoutAnalysisHealthState.healthy()
    : this._(status: WorkoutAnalysisHealthStatus.healthy);

  const WorkoutAnalysisHealthState.recovering({
    required WorkoutAnalysisFailureKind failureKind,
    required int consecutiveFailureCount,
  }) : this._(
         status: WorkoutAnalysisHealthStatus.recovering,
         failureKind: failureKind,
         consecutiveFailureCount: consecutiveFailureCount,
       );

  const WorkoutAnalysisHealthState.blocked({
    required WorkoutAnalysisFailureKind failureKind,
    required int consecutiveFailureCount,
  }) : this._(
         status: WorkoutAnalysisHealthStatus.blocked,
         failureKind: failureKind,
         consecutiveFailureCount: consecutiveFailureCount,
       );

  final WorkoutAnalysisHealthStatus status;
  final WorkoutAnalysisFailureKind? failureKind;
  final int consecutiveFailureCount;

  bool get isHealthy => status == WorkoutAnalysisHealthStatus.healthy;
  bool get isRecovering => status == WorkoutAnalysisHealthStatus.recovering;
  bool get isBlocked => status == WorkoutAnalysisHealthStatus.blocked;
}
