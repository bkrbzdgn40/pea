import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_stabilizer.dart';

void main() {
  group('RangeRepSideStabilizer', () {
    test('confirms a mild side switch only after the second frame', () {
      final stabilizer = RangeRepSideStabilizer();
      final selection = _selection(
        selectedSide: RangeRepSide.right,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: true,
          hasFormMetric: false,
          sideConfidence: 0.80,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.85,
        ),
        reason: RangeRepSideSelectionReason.switchedToHigherCoverage,
      );

      final first = stabilizer.stabilizeSelection(
        selection: selection,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );
      final firstHysteresisStatus = stabilizer.hysteresisStatus;
      final second = stabilizer.stabilizeSelection(
        selection: selection,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );
      final secondHysteresisStatus = stabilizer.hysteresisStatus;

      expect(first.selectedSide, RangeRepSide.left);
      expect(first.reason, RangeRepSideSelectionReason.keptPreviousSide);
      expect(firstHysteresisStatus, 'hold:right 1/2');
      expect(second.selectedSide, RangeRepSide.right);
      expect(
        second.reason,
        RangeRepSideSelectionReason.switchedToHigherCoverage,
      );
      expect(secondHysteresisStatus, 'confirm:right');
      expect(stabilizer.consistencyStatus, isNull);
    });

    test('switches immediately when the current side loses all coverage', () {
      final stabilizer = RangeRepSideStabilizer();
      final selection = _selection(
        selectedSide: RangeRepSide.right,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: false,
          hasFormMetric: false,
          sideConfidence: 0.30,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.90,
        ),
      );

      final result = stabilizer.stabilizeSelection(
        selection: selection,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );

      expect(result.selectedSide, RangeRepSide.right);
      expect(result.reason, RangeRepSideSelectionReason.selectedHigherCoverage);
      expect(stabilizer.hysteresisStatus, 'switch:right');
      expect(stabilizer.consistencyStatus, isNull);
    });

    test('holds the anchored rep side until a strong switch is confirmed', () {
      final stabilizer = RangeRepSideStabilizer();
      final anchorSelection = _selection(
        selectedSide: RangeRepSide.left,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.75,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: false,
          sideConfidence: 0.55,
        ),
        reason: RangeRepSideSelectionReason.keptPreviousSide,
      );
      final switchCandidate = _selection(
        selectedSide: RangeRepSide.right,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: false,
          hasFormMetric: false,
          sideConfidence: 0.20,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.95,
        ),
        reason: RangeRepSideSelectionReason.switchedToHigherCoverage,
      );

      final anchored = stabilizer.stabilizeSelection(
        selection: anchorSelection,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: true,
      );
      final anchorHysteresisStatus = stabilizer.hysteresisStatus;
      final anchorConsistencyStatus = stabilizer.consistencyStatus;
      final held = stabilizer.stabilizeSelection(
        selection: switchCandidate,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: true,
      );
      final heldHysteresisStatus = stabilizer.hysteresisStatus;
      final heldConsistencyStatus = stabilizer.consistencyStatus;
      final switched = stabilizer.stabilizeSelection(
        selection: switchCandidate,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: true,
      );
      final switchedHysteresisStatus = stabilizer.hysteresisStatus;
      final switchedConsistencyStatus = stabilizer.consistencyStatus;

      expect(anchored.selectedSide, RangeRepSide.left);
      expect(anchorHysteresisStatus, 'stay:left');
      expect(anchorConsistencyStatus, 'anchor:left');
      expect(held.selectedSide, RangeRepSide.left);
      expect(
        held.reason,
        RangeRepSideSelectionReason.keptPreviousSideWithoutCoverage,
      );
      expect(heldHysteresisStatus, 'switch:right');
      expect(heldConsistencyStatus, 'hold:right 1/2');
      expect(switched.selectedSide, RangeRepSide.right);
      expect(
        switched.reason,
        RangeRepSideSelectionReason.switchedToHigherCoverage,
      );
      expect(switchedHysteresisStatus, 'switch:right');
      expect(switchedConsistencyStatus, 'switch:right');
    });

    test('drops the anchored side lock once the rep context is inactive', () {
      final stabilizer = RangeRepSideStabilizer();
      final anchorSelection = _selection(
        selectedSide: RangeRepSide.left,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.75,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: false,
          sideConfidence: 0.55,
        ),
        reason: RangeRepSideSelectionReason.keptPreviousSide,
      );
      final switchCandidate = _selection(
        selectedSide: RangeRepSide.right,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: false,
          hasFormMetric: false,
          sideConfidence: 0.20,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.95,
        ),
      );

      stabilizer.stabilizeSelection(
        selection: anchorSelection,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: true,
      );
      final result = stabilizer.stabilizeSelection(
        selection: switchCandidate,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );

      expect(result.selectedSide, RangeRepSide.right);
      expect(result.reason, RangeRepSideSelectionReason.selectedHigherCoverage);
      expect(stabilizer.hysteresisStatus, 'switch:right');
      expect(stabilizer.consistencyStatus, isNull);
    });
  });
}

RangeRepSideSelection _selection({
  required RangeRepSide? selectedSide,
  required RangeRepSideMetrics left,
  required RangeRepSideMetrics right,
  RangeRepSideSelectionReason reason =
      RangeRepSideSelectionReason.selectedHigherCoverage,
}) {
  return RangeRepSideSelection(
    selectedSide: selectedSide,
    leftMetrics: left,
    rightMetrics: right,
    reason: reason,
  );
}

RangeRepSideMetrics _sideMetrics(
  RangeRepSide side, {
  required bool hasPrimaryAngle,
  required bool hasFormMetric,
  double? sideConfidence,
}) {
  return RangeRepSideMetrics(
    side: side,
    primaryAngle: hasPrimaryAngle ? 120.0 : 180.0,
    formMetric: hasFormMetric ? 60.0 : 90.0,
    hasPrimaryAngle: hasPrimaryAngle,
    hasFormMetric: hasFormMetric,
    sideConfidence: sideConfidence,
  );
}
