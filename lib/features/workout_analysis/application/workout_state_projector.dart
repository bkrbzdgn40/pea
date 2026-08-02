import '../domain/models/validated_rep_event.dart';
import 'hold_coordinator.dart';
import 'range_rep_coordinator.dart';
import 'workout_state.dart';

/// Converts coordinator snapshots into the immutable state consumed by the UI.
///
/// The projector is intentionally pure: feedback text is resolved by the
/// caller and no provider, clock, diagnostics, or delivery side effect is
/// available here.
class WorkoutStateProjector {
  const WorkoutStateProjector();

  WorkoutState initialRangeRep({
    required String feedbackMessage,
    required String currentPhase,
  }) {
    return WorkoutState.rangeRep(
      feedbackMessage: feedbackMessage,
      analysis: RangeRepWorkoutAnalysisState(currentPhase: currentPhase),
    );
  }

  WorkoutState initialHold({
    required HoldCoordinatorStateSnapshot snapshot,
    required String feedbackMessage,
  }) {
    return WorkoutState.hold(
      feedbackMessage: feedbackMessage,
      analysis: _holdAnalysis(snapshot),
    );
  }

  WorkoutState rangeRep({
    required RangeRepCoordinatorStateSnapshot snapshot,
    required String feedbackMessage,
    required double cameraFps,
    required double analysisFps,
    ValidatedRepEvent? validatedRepEvent,
  }) {
    return WorkoutState.rangeRep(
      landmarks: snapshot.landmarks,
      feedbackMessage: feedbackMessage,
      cameraFps: cameraFps,
      analysisFps: analysisFps,
      analysis: RangeRepWorkoutAnalysisState(
        repCount: snapshot.repCount,
        isFormBad: snapshot.isFormBad,
        currentAngle: snapshot.currentAngle,
        lastRepScore: snapshot.lastRepScore,
        lastRepRom: snapshot.lastRepRom,
        currentPhase: snapshot.currentPhase,
        calibrationMetrics: snapshot.calibrationMetrics,
        techniqueObservations: snapshot.techniqueObservations,
        validatedRepEvent: validatedRepEvent,
      ),
    );
  }

  WorkoutState hold({
    required HoldCoordinatorStateSnapshot snapshot,
    required String feedbackMessage,
    required double cameraFps,
    required double analysisFps,
  }) {
    return WorkoutState.hold(
      landmarks: snapshot.landmarks,
      feedbackMessage: feedbackMessage,
      cameraFps: cameraFps,
      analysisFps: analysisFps,
      analysis: _holdAnalysis(snapshot),
    );
  }

  HoldWorkoutAnalysisState _holdAnalysis(
    HoldCoordinatorStateSnapshot snapshot,
  ) {
    return HoldWorkoutAnalysisState(
      isFormBad: snapshot.isFormBad,
      currentAngle: snapshot.currentAngle,
      currentHoldSeconds: snapshot.currentHoldSeconds,
      bestHoldSeconds: snapshot.bestHoldSeconds,
      selectedHoldSide: snapshot.selectedHoldSide,
      holdFeedbackCode: snapshot.holdFeedbackCode,
      holdEnginePhase: snapshot.holdEnginePhase,
      isHolding: snapshot.isHolding,
      isHoldVisibilitySuspended: snapshot.isHoldVisibilitySuspended,
      hadHoldFormBreak: snapshot.hadHoldFormBreak,
      currentPhase: snapshot.currentPhase,
      calibrationMetrics: snapshot.calibrationMetrics,
      holdTechniqueAssessment: snapshot.holdTechniqueAssessment,
      plankHipDeviation: snapshot.plankHipDeviation,
      plankShoulderElbowOffset: snapshot.plankShoulderElbowOffset,
      hollowShoulderElevation: snapshot.hollowShoulderElevation,
      hollowHeelElevation: snapshot.hollowHeelElevation,
    );
  }
}
