import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  group('WorkoutState family invariants', () {
    test(
      'range-rep state exposes range-rep payload and hold compatibility defaults',
      () {
        final state = WorkoutState.rangeRep(
          feedbackMessage: 'Asagi in',
          analysis: const RangeRepWorkoutAnalysisState(
            repCount: 2,
            isFormBad: true,
            currentAngle: 95,
            lastRepScore: 82,
            lastRepRom: 104,
            currentPhase: 'PEAK',
            calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(),
          ),
        );

        expect(state.analysisKind.name, 'rangeRep');
        expect(state.rangeRepAnalysis, isNotNull);
        expect(state.holdAnalysis, isNull);
        expect(state.repCount, 2);
        expect(state.isFormBad, isTrue);
        expect(state.currentAngle, 95);
        expect(state.lastRepScore, 82);
        expect(state.lastRepROM, 104);
        expect(state.currentPhase, 'PEAK');
        expect(state.currentHoldSeconds, 0);
        expect(state.bestHoldSeconds, 0);
        expect(state.isHolding, isFalse);
        expect(state.selectedHoldSide, isNull);
        expect(state.calibrationMetrics.analysisKind.name, 'rangeRep');
      },
    );

    test('hold state exposes hold payload and rep compatibility defaults', () {
      final state = WorkoutState.hold(
        feedbackMessage: 'Pozisyonu koru',
        analysis: const HoldWorkoutAnalysisState(
          isFormBad: false,
          currentAngle: 170,
          currentHoldSeconds: 5,
          bestHoldSeconds: 7,
          selectedHoldSide: HoldSide.left,
          holdFeedbackCode: HoldFeedbackCode.holdPosition,
          holdEnginePhase: HoldPhase.holding,
          isHolding: true,
          isHoldVisibilitySuspended: false,
          hadHoldFormBreak: true,
          currentPhase: 'HOLDING',
          calibrationMetrics: WorkoutCalibrationMetrics.hold(),
        ),
      );

      expect(state.analysisKind.name, 'hold');
      expect(state.holdAnalysis, isNotNull);
      expect(state.rangeRepAnalysis, isNull);
      expect(state.currentHoldSeconds, 5);
      expect(state.bestHoldSeconds, 7);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.isHolding, isTrue);
      expect(state.hadHoldFormBreak, isTrue);
      expect(state.currentPhase, 'HOLDING');
      expect(state.repCount, 0);
      expect(state.lastRepScore, 0);
      expect(state.lastRepROM, 0);
      expect(state.calibrationMetrics.analysisKind.name, 'hold');
    });
  });

  group('WorkoutState copyWith', () {
    test('common shell updates preserve range-rep payload', () {
      final state = WorkoutState.rangeRep(
        feedbackMessage: 'Baslangic',
        analysis: const RangeRepWorkoutAnalysisState(
          repCount: 1,
          currentPhase: 'ASCENDING',
        ),
      );

      final copied = state.copyWith(
        feedbackMessage: 'Guncel',
        cameraFps: 30,
        analysisFps: 9,
      );

      expect(copied.analysisKind.name, 'rangeRep');
      expect(copied.repCount, 1);
      expect(copied.currentPhase, 'ASCENDING');
      expect(copied.feedbackMessage, 'Guncel');
      expect(copied.cameraFps, 30);
      expect(copied.analysisFps, 9);
    });

    test('range-rep payload can update without creating mixed state', () {
      final state = WorkoutState.rangeRep(
        analysis: const RangeRepWorkoutAnalysisState(
          repCount: 1,
          lastRepScore: 70,
          currentPhase: 'NEUTRAL',
        ),
      );

      final copied = state.copyWithRangeRepAnalysis(
        state.rangeRepAnalysis!.copyWith(
          repCount: 2,
          lastRepScore: 88,
          currentPhase: 'PEAK',
        ),
      );

      expect(copied.analysisKind.name, 'rangeRep');
      expect(copied.repCount, 2);
      expect(copied.lastRepScore, 88);
      expect(copied.currentPhase, 'PEAK');
      expect(copied.holdAnalysis, isNull);
    });

    test('hold payload can update and clear nullable typed fields', () {
      final state = WorkoutState.hold(
        analysis: const HoldWorkoutAnalysisState(
          currentHoldSeconds: 4,
          selectedHoldSide: HoldSide.right,
          holdFeedbackCode: HoldFeedbackCode.alignHips,
          holdEnginePhase: HoldPhase.broken,
          isHolding: true,
          currentPhase: 'HOLDING',
        ),
      );

      final copied = state.copyWithHoldAnalysis(
        state.holdAnalysis!.copyWith(
          currentHoldSeconds: 0,
          selectedHoldSide: null,
          holdFeedbackCode: null,
          holdEnginePhase: null,
          isHolding: false,
          currentPhase: 'READY',
        ),
      );

      expect(copied.analysisKind.name, 'hold');
      expect(copied.currentHoldSeconds, 0);
      expect(copied.selectedHoldSide, isNull);
      expect(copied.holdFeedbackCode, isNull);
      expect(copied.holdEnginePhase, isNull);
      expect(copied.isHolding, isFalse);
      expect(copied.currentPhase, 'READY');
      expect(copied.repCount, 0);
    });

    test('copyWith blocks cross-family payload swaps', () {
      final rangeRep = WorkoutState.rangeRep();
      final hold = WorkoutState.hold();

      expect(
        () => rangeRep.copyWith(holdAnalysis: const HoldWorkoutAnalysisState()),
        throwsArgumentError,
      );
      expect(
        () => hold.copyWith(
          rangeRepAnalysis: const RangeRepWorkoutAnalysisState(),
        ),
        throwsArgumentError,
      );
    });
  });
}
