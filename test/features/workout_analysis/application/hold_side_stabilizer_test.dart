import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_side_stabilizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  group('HoldSideStabilizer', () {
    test('acquires the first accepted side immediately', () {
      final stabilizer = HoldSideStabilizer();

      final selection = stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.right},
        currentSide: null,
      );

      expect(selection.selectedSide, HoldSide.right);
      expect(selection.reason, HoldSideSelectionReason.selectedPreferredSide);
      expect(stabilizer.status, 'acquire:right');
    });

    test('keeps the previous side until the switch is reconfirmed', () {
      final stabilizer = HoldSideStabilizer();

      final firstSwitchAttempt = stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.left, HoldSide.right},
        currentSide: HoldSide.left,
      );

      expect(firstSwitchAttempt.selectedSide, HoldSide.left);
      expect(
        firstSwitchAttempt.reason,
        HoldSideSelectionReason.keptPreviousSide,
      );
      expect(stabilizer.status, 'hold:right 1/2');
    });

    test('confirms a side switch after two consecutive preferred frames', () {
      final stabilizer = HoldSideStabilizer();

      stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.left, HoldSide.right},
        currentSide: HoldSide.left,
      );
      final confirmedSwitch = stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.left, HoldSide.right},
        currentSide: HoldSide.left,
      );

      expect(confirmedSwitch.selectedSide, HoldSide.right);
      expect(confirmedSwitch.reason, HoldSideSelectionReason.confirmedSwitch);
      expect(stabilizer.status, 'confirm:right');
    });

    test('reset clears pending switch state', () {
      final stabilizer = HoldSideStabilizer();

      stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.left, HoldSide.right},
        currentSide: HoldSide.left,
      );
      stabilizer.reset();

      final nextAttempt = stabilizer.stabilizeSelection(
        preferredSide: HoldSide.right,
        acceptedSides: const <HoldSide>{HoldSide.left, HoldSide.right},
        currentSide: HoldSide.left,
      );

      expect(nextAttempt.selectedSide, HoldSide.left);
      expect(nextAttempt.reason, HoldSideSelectionReason.keptPreviousSide);
      expect(stabilizer.status, 'hold:right 1/2');
    });
  });
}
