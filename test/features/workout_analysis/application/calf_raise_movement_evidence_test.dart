import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/calf_raise_movement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/calf_raise_range_rep_analysis_extension.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_exercise_analysis_extension.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const policy = CalfRaiseMovementEvidencePolicy();
  const neutral = CalfRaisePoseSample(
    heelToForefootSpan: 5,
    ankleToForefootSpan: 10,
    hipToForefootSpan: 60,
    bodyScale: 60,
    forefootX: 10,
    forefootY: 100,
    torsoInclinationDegrees: 0,
  );

  group('CalfRaiseMovementEvidencePolicy', () {
    test('accepts coordinated heel, ankle, and body elevation', () {
      const raised = CalfRaisePoseSample(
        heelToForefootSpan: 9,
        ankleToForefootSpan: 14,
        hipToForefootSpan: 64,
        bodyScale: 64,
        forefootX: 10,
        forefootY: 100,
        torsoInclinationDegrees: 2,
      );

      final evidence = policy.evaluate(baseline: neutral, current: raised);

      expect(evidence.isCalfRaise, isTrue);
      expect(evidence.heelElevationRatio, closeTo(4 / 60, 0.0001));
    });

    test('rejects ankle and hip drift when the heel stays planted', () {
      const hingeDrift = CalfRaisePoseSample(
        heelToForefootSpan: 5,
        ankleToForefootSpan: 14,
        hipToForefootSpan: 64,
        bodyScale: 64,
        forefootX: 10,
        forefootY: 100,
        torsoInclinationDegrees: 18,
      );

      final evidence = policy.evaluate(baseline: neutral, current: hingeDrift);

      expect(evidence.isCalfRaise, isFalse);
      expect(evidence.heelElevationRatio, 0);
    });

    test('rejects a large torso-axis change despite apparent heel lift', () {
      const hingeWithFootJitter = CalfRaisePoseSample(
        heelToForefootSpan: 9,
        ankleToForefootSpan: 14,
        hipToForefootSpan: 64,
        bodyScale: 64,
        forefootX: 10,
        forefootY: 100,
        torsoInclinationDegrees: 25,
      );

      final evidence = policy.evaluate(
        baseline: neutral,
        current: hingeWithFootJitter,
      );

      expect(evidence.isCalfRaise, isFalse);
      expect(evidence.torsoInclinationDeltaDegrees, 25);
    });
  });

  group('CalfRaiseRangeRepAnalysisExtension', () {
    test(
      'uses the coordinator-selected side instead of the strongest raw side',
      () {
        final extension = CalfRaiseRangeRepAnalysisExtension();
        final startedAt = DateTime.utc(2030, 1, 1);

        extension.adaptPrimaryMetric(
          _context(
            metrics: _bilateralMetrics(leftRaised: false, rightRaised: false),
            selectedSide: RangeRepSide.right,
            primaryMetric: 110,
            phase: rangeRepAwaitNeutralPhaseLabel,
            now: startedAt,
          ),
        );
        extension.adaptPrimaryMetric(
          _context(
            metrics: _bilateralMetrics(leftRaised: false, rightRaised: false),
            selectedSide: RangeRepSide.right,
            primaryMetric: 110,
            phase: 'NEUTRAL',
            now: startedAt.add(const Duration(milliseconds: 140)),
          ),
        );

        final adapted = extension.adaptPrimaryMetric(
          _context(
            metrics: _bilateralMetrics(
              leftRaised: true,
              rightRaised: false,
              leftPrimaryMetric: 159,
              rightPrimaryMetric: 146,
            ),
            selectedSide: RangeRepSide.right,
            primaryMetric: 146,
            phase: 'NEUTRAL',
            now: startedAt.add(const Duration(milliseconds: 280)),
          ),
        );

        expect(adapted, 121);
      },
    );

    test('passes a selected-side frame with real heel and body elevation', () {
      final extension = CalfRaiseRangeRepAnalysisExtension();
      final startedAt = DateTime.utc(2030, 1, 1);

      for (var index = 0; index < 2; index += 1) {
        extension.adaptPrimaryMetric(
          _context(
            metrics: _bilateralMetrics(leftRaised: false, rightRaised: false),
            selectedSide: RangeRepSide.right,
            primaryMetric: 110,
            phase: index == 0 ? rangeRepAwaitNeutralPhaseLabel : 'NEUTRAL',
            now: startedAt.add(Duration(milliseconds: index * 140)),
          ),
        );
      }

      final adapted = extension.adaptPrimaryMetric(
        _context(
          metrics: _bilateralMetrics(
            leftRaised: false,
            rightRaised: true,
            leftPrimaryMetric: 110,
            rightPrimaryMetric: 146,
          ),
          selectedSide: RangeRepSide.right,
          primaryMetric: 146,
          phase: 'NEUTRAL',
          now: startedAt.add(const Duration(milliseconds: 280)),
        ),
      );

      expect(adapted, 146);
    });
  });
}

RangeRepDetectionFrameContext _context({
  required ExerciseMetrics metrics,
  required RangeRepSide selectedSide,
  required double primaryMetric,
  required String phase,
  required DateTime now,
}) {
  return RangeRepDetectionFrameContext(
    metrics: metrics,
    selectedSide: selectedSide,
    primaryMetric: primaryMetric,
    neutralThreshold: 120,
    activeThreshold: 121,
    currentPhase: phase,
    hasActiveRepContext: false,
    now: now,
  );
}

ExerciseMetrics _bilateralMetrics({
  required bool leftRaised,
  required bool rightRaised,
  double leftPrimaryMetric = 110,
  double rightPrimaryMetric = 110,
}) {
  return ExerciseMetrics(
    primaryAngle: 110,
    formMetric: 175,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: <PoseLandmark>[
      ..._sideLandmarks(side: RangeRepSide.left, raised: leftRaised),
      ..._sideLandmarks(side: RangeRepSide.right, raised: rightRaised),
    ],
    leftRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.left,
      primaryAngle: leftPrimaryMetric,
      formMetric: 175,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      sideConfidence: 1,
    ),
    rightRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.right,
      primaryAngle: rightPrimaryMetric,
      formMetric: 175,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      sideConfidence: 1,
    ),
  );
}

List<PoseLandmark> _sideLandmarks({
  required RangeRepSide side,
  required bool raised,
}) {
  final verticalOffset = raised ? 4.0 : 0.0;
  final xOffset = side == RangeRepSide.left ? 0.0 : 100.0;
  final shoulder = side == RangeRepSide.left
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final hip = side == RangeRepSide.left
      ? PoseLandmarkType.leftHip
      : PoseLandmarkType.rightHip;
  final ankle = side == RangeRepSide.left
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;
  final heel = side == RangeRepSide.left
      ? PoseLandmarkType.leftHeel
      : PoseLandmarkType.rightHeel;
  final forefoot = side == RangeRepSide.left
      ? PoseLandmarkType.leftFootIndex
      : PoseLandmarkType.rightFootIndex;

  return <PoseLandmark>[
    buildLandmark(shoulder, xOffset, 15 - verticalOffset),
    buildLandmark(hip, xOffset, 40 - verticalOffset),
    buildLandmark(ankle, xOffset, 90 - verticalOffset),
    buildLandmark(heel, xOffset, 95 - verticalOffset),
    buildLandmark(forefoot, xOffset + 10, 100),
  ];
}
