import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  group('shouldLockRangeRepSideSelection', () {
    test('returns false for non-range-rep engines', () {
      final shouldLock = shouldLockRangeRepSideSelection(
        engineKind: EngineKind.hold,
        selectedSide: RangeRepSide.left,
        diagnostics: const RangeRepDiagnosticsSnapshot(hasActiveRepPhase: true),
      );

      expect(shouldLock, isFalse);
    });

    test('returns false when no side is currently selected', () {
      final shouldLock = shouldLockRangeRepSideSelection(
        engineKind: EngineKind.rangeRep,
        selectedSide: null,
        diagnostics: const RangeRepDiagnosticsSnapshot(hasPendingTransition: true),
      );

      expect(shouldLock, isFalse);
    });

    test('returns true while an active rep phase is running', () {
      final shouldLock = shouldLockRangeRepSideSelection(
        engineKind: EngineKind.rangeRep,
        selectedSide: RangeRepSide.right,
        diagnostics: const RangeRepDiagnosticsSnapshot(hasActiveRepPhase: true),
      );

      expect(shouldLock, isTrue);
    });

    test('returns true while a transition is still pending', () {
      final shouldLock = shouldLockRangeRepSideSelection(
        engineKind: EngineKind.rangeRep,
        selectedSide: RangeRepSide.left,
        diagnostics: const RangeRepDiagnosticsSnapshot(
          hasPendingTransition: true,
          pendingTransitionLabel: 'neutral -> descending',
        ),
      );

      expect(shouldLock, isTrue);
    });
  });
}
