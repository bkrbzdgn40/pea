import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';

void main() {
  test('default typed hold fields are null', () {
    final state = WorkoutState();

    expect(state.holdFeedbackCode, isNull);
    expect(state.holdEnginePhase, isNull);
  });

  test('copyWith preserves typed hold fields by default', () {
    final state = WorkoutState(
      holdFeedbackCode: HoldFeedbackCode.holdPosition,
      holdEnginePhase: HoldPhase.holding,
      feedbackMessage: 'Pozisyonu Koru',
      currentPhase: 'HOLDING',
    );

    final copied = state.copyWith(currentHoldSeconds: 5);

    expect(copied.holdFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(copied.holdEnginePhase, HoldPhase.holding);
    expect(copied.feedbackMessage, 'Pozisyonu Koru');
    expect(copied.currentPhase, 'HOLDING');
  });

  test('copyWith can clear typed hold fields with null', () {
    final state = WorkoutState(
      holdFeedbackCode: HoldFeedbackCode.alignHips,
      holdEnginePhase: HoldPhase.broken,
    );

    final copied = state.copyWith(
      holdFeedbackCode: null,
      holdEnginePhase: null,
    );

    expect(copied.holdFeedbackCode, isNull);
    expect(copied.holdEnginePhase, isNull);
  });

  test(
    'typed hold fields can change without altering UI compatibility fields',
    () {
      final state = WorkoutState(
        holdFeedbackCode: HoldFeedbackCode.preparePosition,
        holdEnginePhase: HoldPhase.ready,
        feedbackMessage: 'Vucut net gorunmuyor.',
        currentPhase: 'WAITING',
      );

      final copied = state.copyWith(
        holdFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        holdEnginePhase: HoldPhase.holding,
      );

      expect(copied.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
      expect(copied.holdEnginePhase, HoldPhase.holding);
      expect(copied.feedbackMessage, 'Vucut net gorunmuyor.');
      expect(copied.currentPhase, 'WAITING');
    },
  );
}
