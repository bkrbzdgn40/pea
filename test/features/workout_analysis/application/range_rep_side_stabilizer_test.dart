import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_stabilizer.dart';

void main() {
  group('RangeRepSideStabilizer', () {
    test(
      'acquires the first side immediately when no side is selected yet',
      () {
        final stabilizer = RangeRepSideStabilizer();

        final stabilized = stabilizer.stabilizeSelection(
          selection: _selection(
            selectedSide: RangeRepSide.right,
            left: _sideMetrics(
              RangeRepSide.left,
              hasPrimaryAngle: false,
              hasFormMetric: false,
              sideConfidence: 0.0,
            ),
            right: _sideMetrics(
              RangeRepSide.right,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              sideConfidence: 0.9,
            ),
          ),
          currentSide: null,
          hasActiveRepContext: false,
        );

        expect(stabilized.selectedSide, RangeRepSide.right);
        expect(stabilizer.hysteresisStatus, 'acquire:right');
        expect(stabilizer.consistencyStatus, isNull);
      },
    );

    test('holds the previous side until a soft switch is reconfirmed', () {
      final stabilizer = RangeRepSideStabilizer();
      final candidate = _selection(
        selectedSide: RangeRepSide.right,
        left: _sideMetrics(
          RangeRepSide.left,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.80,
        ),
        right: _sideMetrics(
          RangeRepSide.right,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 0.85,
        ),
      );

      final firstPass = stabilizer.stabilizeSelection(
        selection: candidate,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );
      expect(firstPass.selectedSide, RangeRepSide.left);
      expect(stabilizer.hysteresisStatus, 'hold:right 1/2');

      final secondPass = stabilizer.stabilizeSelection(
        selection: candidate,
        currentSide: RangeRepSide.left,
        hasActiveRepContext: false,
      );
      expect(secondPass.selectedSide, RangeRepSide.right);
      expect(stabilizer.hysteresisStatus, 'confirm:right');
    });

    test(
      'keeps the active rep side anchored until a strong switch repeats',
      () {
        final stabilizer = RangeRepSideStabilizer();

        stabilizer.stabilizeSelection(
          selection: _selection(
            selectedSide: RangeRepSide.left,
            left: _sideMetrics(
              RangeRepSide.left,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              sideConfidence: 0.80,
            ),
            right: _sideMetrics(
              RangeRepSide.right,
              hasPrimaryAngle: false,
              hasFormMetric: false,
              sideConfidence: 0.10,
            ),
          ),
          currentSide: RangeRepSide.left,
          hasActiveRepContext: true,
        );

        final strongRightCandidate = _selection(
          selectedSide: RangeRepSide.right,
          left: _sideMetrics(
            RangeRepSide.left,
            hasPrimaryAngle: true,
            hasFormMetric: false,
            sideConfidence: 0.50,
          ),
          right: _sideMetrics(
            RangeRepSide.right,
            hasPrimaryAngle: true,
            hasFormMetric: true,
            sideConfidence: 0.90,
          ),
        );

        final firstPass = stabilizer.stabilizeSelection(
          selection: strongRightCandidate,
          currentSide: RangeRepSide.left,
          hasActiveRepContext: true,
        );
        expect(firstPass.selectedSide, RangeRepSide.left);
        expect(stabilizer.consistencyStatus, 'hold:right 1/2');

        final secondPass = stabilizer.stabilizeSelection(
          selection: strongRightCandidate,
          currentSide: RangeRepSide.left,
          hasActiveRepContext: true,
        );
        expect(secondPass.selectedSide, RangeRepSide.right);
        expect(stabilizer.consistencyStatus, 'switch:right');
      },
    );

    test('reset clears hysteresis and rep-consistency state', () {
      final stabilizer = RangeRepSideStabilizer();

      stabilizer.stabilizeSelection(
        selection: _selection(
          selectedSide: RangeRepSide.left,
          left: _sideMetrics(
            RangeRepSide.left,
            hasPrimaryAngle: true,
            hasFormMetric: true,
            sideConfidence: 0.80,
          ),
          right: _sideMetrics(
            RangeRepSide.right,
            hasPrimaryAngle: false,
            hasFormMetric: false,
            sideConfidence: 0.10,
          ),
        ),
        currentSide: RangeRepSide.left,
        hasActiveRepContext: true,
      );
      stabilizer.reset();

      expect(stabilizer.hysteresisStatus, isNull);
      expect(stabilizer.consistencyStatus, isNull);
    });
  });
}

RangeRepSideSelection _selection({
  required RangeRepSide selectedSide,
  required RangeRepSideMetrics left,
  required RangeRepSideMetrics right,
}) {
  return RangeRepSideSelection(
    selectedSide: selectedSide,
    leftMetrics: left,
    rightMetrics: right,
    reason: RangeRepSideSelectionReason.selectedHigherCoverage,
  );
}

RangeRepSideMetrics _sideMetrics(
  RangeRepSide side, {
  required bool hasPrimaryAngle,
  required bool hasFormMetric,
  required double sideConfidence,
}) {
  return RangeRepSideMetrics(
    side: side,
    primaryAngle: hasPrimaryAngle ? 100.0 : 180.0,
    formMetric: hasFormMetric ? 70.0 : 90.0,
    hasPrimaryAngle: hasPrimaryAngle,
    hasFormMetric: hasFormMetric,
    sideConfidence: sideConfidence,
  );
}
