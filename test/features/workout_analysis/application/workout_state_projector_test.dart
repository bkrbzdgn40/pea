import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state_projector.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';

void main() {
  const projector = WorkoutStateProjector();

  test('projects the initial range-rep state without side effects', () {
    final state = projector.initialRangeRep(
      feedbackMessage: 'ready',
      currentPhase: 'NEUTRAL',
    );

    expect(state.feedbackMessage, 'ready');
    expect(state.currentPhase, 'NEUTRAL');
    expect(state.repCount, 0);
    expect(state.cameraFps, 0.0);
    expect(state.analysisFps, 0.0);
  });

  test('projects a range-rep coordinator snapshot exactly', () {
    const snapshot = RangeRepCoordinatorStateSnapshot(
      landmarks: null,
      repCount: 3,
      isFormBad: true,
      currentAngle: 91,
      lastRepScore: 82,
      lastRepRom: 76,
      currentPhase: 'PEAK',
      calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(),
      feedbackDirective: RangeRepFeedbackDirective.code(
        RangeRepFeedbackCode.ascend,
      ),
    );

    final state = projector.rangeRep(
      snapshot: snapshot,
      feedbackMessage: 'ascend',
      cameraFps: 29.5,
      analysisFps: 9.5,
    );

    expect(state.repCount, 3);
    expect(state.isFormBad, isTrue);
    expect(state.currentAngle, 91);
    expect(state.lastRepScore, 82);
    expect(state.lastRepROM, 76);
    expect(state.currentPhase, 'PEAK');
    expect(state.feedbackMessage, 'ascend');
    expect(state.cameraFps, 29.5);
    expect(state.analysisFps, 9.5);
  });

  test('keeps initial and published hold projection semantics distinct', () {
    const snapshot = HoldCoordinatorStateSnapshot(
      landmarks: null,
      isFormBad: true,
      currentAngle: 171,
      currentHoldSeconds: 8,
      bestHoldSeconds: 12,
      selectedHoldSide: HoldSide.left,
      isHolding: true,
      isHoldVisibilitySuspended: false,
      hadHoldFormBreak: true,
      holdFeedbackCode: HoldFeedbackCode.holdPosition,
      holdEnginePhase: HoldPhase.holding,
      currentPhase: 'HOLDING',
      calibrationMetrics: WorkoutCalibrationMetrics.hold(),
      feedbackFallbackMessage: 'hold',
    );

    final initial = projector.initialHold(
      snapshot: snapshot,
      feedbackMessage: 'initial hold',
    );
    final published = projector.hold(
      snapshot: snapshot,
      feedbackMessage: 'hold',
      cameraFps: 30,
      analysisFps: 10,
    );

    expect(initial.landmarks, isNull);
    expect(initial.feedbackMessage, 'initial hold');
    expect(initial.cameraFps, 0.0);
    expect(initial.analysisFps, 0.0);
    expect(initial.currentHoldSeconds, 8);

    expect(published.currentHoldSeconds, 8);
    expect(published.bestHoldSeconds, 12);
    expect(published.selectedHoldSide, HoldSide.left);
    expect(published.isHolding, isTrue);
    expect(published.hadHoldFormBreak, isTrue);
    expect(published.feedbackMessage, 'hold');
    expect(published.cameraFps, 30);
    expect(published.analysisFps, 10);
  });
}
