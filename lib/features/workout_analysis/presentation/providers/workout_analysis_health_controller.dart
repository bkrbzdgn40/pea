import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_analysis_failure_policy.dart';
import '../models/workout_analysis_health_state.dart';
import 'active_analysis_exercise_provider.dart';

final workoutAnalysisHealthControllerProvider =
    AutoDisposeNotifierProvider<
      WorkoutAnalysisHealthController,
      WorkoutAnalysisHealthState
    >(WorkoutAnalysisHealthController.new);

class WorkoutAnalysisHealthController
    extends AutoDisposeNotifier<WorkoutAnalysisHealthState> {
  @override
  WorkoutAnalysisHealthState build() {
    ref.watch(activeAnalysisExerciseProvider);
    return const WorkoutAnalysisHealthState.healthy();
  }

  void publish(WorkoutAnalysisFailureDecision decision) {
    state = decision.isBlocked
        ? WorkoutAnalysisHealthState.blocked(
            failureKind: decision.kind,
            consecutiveFailureCount: decision.consecutiveFailureCount,
          )
        : WorkoutAnalysisHealthState.recovering(
            failureKind: decision.kind,
            consecutiveFailureCount: decision.consecutiveFailureCount,
          );
  }

  void markHealthy() {
    if (state.isHealthy) {
      return;
    }
    state = const WorkoutAnalysisHealthState.healthy();
  }

  void reset() {
    state = const WorkoutAnalysisHealthState.healthy();
  }
}
