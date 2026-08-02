import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_temporal_continuity_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';

void main() {
  group('RangeRepTemporalContinuityTracker', () {
    test(
      'first frame stays unknown instead of inventing perfect continuity',
      () {
        final tracker = RangeRepTemporalContinuityTracker();

        final result = tracker.evaluate(
          pose: _leftPose(movingX: 2),
          side: RangeRepSide.left,
          requirementSet: _leftRequirements,
          seed: _seed(),
          observedAt: _time(0),
        );

        expect(result.temporalContinuity, isNull);
        expect(result.combined, isNull);
        expect(
          result.issues,
          contains(MeasurementConfidenceIssue.temporalHistoryUnavailable),
        );
      },
    );

    test('similar second frame has high continuity', () {
      final tracker = RangeRepTemporalContinuityTracker();
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );

      final result = tracker.evaluate(
        pose: _leftPose(movingX: 2.1),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      expect(result.temporalContinuity, greaterThan(0.95));
      expect(result.combined, isNotNull);
      expect(
        result.issues,
        isNot(contains(MeasurementConfidenceIssue.temporalDiscontinuity)),
      );
    });

    test('large normalized single-frame jump has low continuity', () {
      final tracker = RangeRepTemporalContinuityTracker();
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );

      final result = tracker.evaluate(
        pose: _leftPose(movingX: 10),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      expect(result.temporalContinuity, lessThan(0.20));
      expect(
        result.issues,
        contains(MeasurementConfidenceIssue.temporalDiscontinuity),
      );
    });

    test(
      'normalization preserves equivalent motion at different image scales',
      () {
        final smallTracker = RangeRepTemporalContinuityTracker();
        final largeTracker = RangeRepTemporalContinuityTracker();

        smallTracker.evaluate(
          pose: _leftPose(movingX: 2, scale: 1),
          side: RangeRepSide.left,
          requirementSet: _leftRequirements,
          seed: _seed(),
          observedAt: _time(0),
        );
        largeTracker.evaluate(
          pose: _leftPose(movingX: 2, scale: 4),
          side: RangeRepSide.left,
          requirementSet: _leftRequirements,
          seed: _seed(),
          observedAt: _time(0),
        );

        final small = smallTracker.evaluate(
          pose: _leftPose(movingX: 3, scale: 1),
          side: RangeRepSide.left,
          requirementSet: _leftRequirements,
          seed: _seed(),
          observedAt: _time(100),
        );
        final large = largeTracker.evaluate(
          pose: _leftPose(movingX: 3, scale: 4),
          side: RangeRepSide.left,
          requirementSet: _leftRequirements,
          seed: _seed(),
          observedAt: _time(100),
        );

        expect(
          large.temporalContinuity,
          closeTo(small.temporalContinuity!, 1e-12),
        );
      },
    );

    test('non-monotonic timestamp cannot produce trusted continuity', () {
      final tracker = RangeRepTemporalContinuityTracker();
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      final result = tracker.evaluate(
        pose: _leftPose(movingX: 2.1),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      expect(result.temporalContinuity, isNull);
      expect(result.combined, isNull);
      expect(
        result.issues,
        contains(MeasurementConfidenceIssue.temporalDiscontinuity),
      );
    });

    test('reset makes the next frame unknown again', () {
      final tracker = RangeRepTemporalContinuityTracker();
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );
      final known = tracker.evaluate(
        pose: _leftPose(movingX: 2.1),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );
      expect(known.temporalContinuity, isNotNull);

      tracker.reset();
      final afterReset = tracker.evaluate(
        pose: _leftPose(movingX: 2.2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(200),
      );

      expect(afterReset.temporalContinuity, isNull);
      expect(
        afterReset.issues,
        contains(MeasurementConfidenceIssue.temporalHistoryUnavailable),
      );
    });

    test('left and right histories do not contaminate each other', () {
      final tracker = RangeRepTemporalContinuityTracker();
      final pose = _bilateralPose(leftMovingX: 2, rightMovingX: 8);

      tracker.evaluate(
        pose: pose,
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );
      final leftKnown = tracker.evaluate(
        pose: _bilateralPose(leftMovingX: 2.1, rightMovingX: 8),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );
      final rightFirst = tracker.evaluate(
        pose: pose,
        side: RangeRepSide.right,
        requirementSet: _rightRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      expect(leftKnown.temporalContinuity, isNotNull);
      expect(rightFirst.temporalContinuity, isNull);
    });

    test('fast but time-consistent movement can remain highly continuous', () {
      final tracker = RangeRepTemporalContinuityTracker();
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );
      tracker.evaluate(
        pose: _leftPose(movingX: 5),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(50),
      );

      final result = tracker.evaluate(
        pose: _leftPose(movingX: 8),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(100),
      );

      expect(result.temporalContinuity, greaterThan(0.95));
      expect(
        result.issues,
        isNot(contains(MeasurementConfidenceIssue.temporalDiscontinuity)),
      );
    });

    test('observation gap discards stale history', () {
      final tracker = RangeRepTemporalContinuityTracker(
        maximumObservationGap: const Duration(milliseconds: 200),
      );
      tracker.evaluate(
        pose: _leftPose(movingX: 2),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(0),
      );

      final result = tracker.evaluate(
        pose: _leftPose(movingX: 2.1),
        side: RangeRepSide.left,
        requirementSet: _leftRequirements,
        seed: _seed(),
        observedAt: _time(500),
      );

      expect(result.temporalContinuity, isNull);
      expect(
        result.issues,
        contains(MeasurementConfidenceIssue.temporalHistoryUnavailable),
      );
    });
  });
}

const _leftRequirements = ExerciseLandmarkRequirementSet(
  requiredLandmarks: <PoseLandmarkType>{
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.leftKnee,
  },
  requiredAngleTriplets: <PoseAngleTriplet>[],
  requiredSegments: <PoseLandmarkSegment>[],
);

const _rightRequirements = ExerciseLandmarkRequirementSet(
  requiredLandmarks: <PoseLandmarkType>{
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.rightKnee,
  },
  requiredAngleTriplets: <PoseAngleTriplet>[],
  requiredSegments: <PoseLandmarkSegment>[],
);

MeasurementConfidenceBreakdown _seed() {
  return MeasurementConfidenceBreakdown(
    landmarkLikelihood: 0.95,
    signalAvailability: 1.0,
    geometryPlausibility: 1.0,
    temporalContinuity: null,
    combined: null,
    issues: const <MeasurementConfidenceIssue>[],
  );
}

DateTime _time(int milliseconds) {
  return DateTime.utc(2030).add(Duration(milliseconds: milliseconds));
}

Pose _leftPose({required double movingX, double scale = 1}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        0,
        scale,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        10,
        10,
        scale,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        movingX,
        5,
        scale,
      ),
    },
  );
}

Pose _bilateralPose({
  required double leftMovingX,
  required double rightMovingX,
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      ..._leftPose(movingX: leftMovingX).landmarks,
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        20,
        0,
        1,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        30,
        10,
        1,
      ),
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        20 + rightMovingX,
        5,
        1,
      ),
    },
  );
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y,
  double scale,
) {
  return PoseLandmark(
    type: type,
    x: x * scale,
    y: y * scale,
    z: 0,
    likelihood: 0.95,
  );
}
