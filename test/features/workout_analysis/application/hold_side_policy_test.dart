import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  group('shouldLockHoldSideSelection', () {
    test('returns false outside hold analysis', () {
      final shouldLock = shouldLockHoldSideSelection(
        engineKind: EngineKind.rangeRep,
        selectedSide: HoldSide.left,
        diagnostics: HoldDiagnosticsSnapshot(isHolding: true),
      );

      expect(shouldLock, isFalse);
    });

    test('returns false when no hold side has been selected', () {
      final shouldLock = shouldLockHoldSideSelection(
        engineKind: EngineKind.hold,
        selectedSide: null,
        diagnostics: HoldDiagnosticsSnapshot(isHolding: true),
      );

      expect(shouldLock, isFalse);
    });

    test('returns true while a hold is active', () {
      final shouldLock = shouldLockHoldSideSelection(
        engineKind: EngineKind.hold,
        selectedSide: HoldSide.right,
        diagnostics: HoldDiagnosticsSnapshot(isHolding: true),
      );

      expect(shouldLock, isTrue);
    });

    test('returns true during a brief visibility gap', () {
      final shouldLock = shouldLockHoldSideSelection(
        engineKind: EngineKind.hold,
        selectedSide: HoldSide.right,
        diagnostics: HoldDiagnosticsSnapshot(isVisibilitySuspended: true),
      );

      expect(shouldLock, isTrue);
    });

    test('returns false after the hold has ended and no gap is active', () {
      final shouldLock = shouldLockHoldSideSelection(
        engineKind: EngineKind.hold,
        selectedSide: HoldSide.left,
        diagnostics: HoldDiagnosticsSnapshot(),
      );

      expect(shouldLock, isFalse);
    });
  });
}
