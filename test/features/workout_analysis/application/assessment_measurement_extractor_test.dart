import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/assessment_measurement_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';

void main() {
  const extractor = AssessmentMeasurementExtractor();

  group('AssessmentMeasurementExtractor', () {
    test('extracts bilateral squat angles, depth, and torso inclination', () {
      final observation = extractor.extractSquat(
        _pose(<PoseLandmarkType, (double, double)>{
          PoseLandmarkType.leftShoulder: (-2, 0),
          PoseLandmarkType.rightShoulder: (2, 0),
          PoseLandmarkType.leftHip: (-2, 2),
          PoseLandmarkType.rightHip: (2, 2),
          PoseLandmarkType.leftKnee: (-1, 2),
          PoseLandmarkType.rightKnee: (1, 2),
          PoseLandmarkType.leftAnkle: (-1, 3),
          PoseLandmarkType.rightAnkle: (1, 3),
        }),
      );

      expect(observation.leftKneeAngleDegrees, closeTo(90, 1e-9));
      expect(observation.rightKneeAngleDegrees, closeTo(90, 1e-9));
      expect(observation.hipDepthRatio, closeTo(0, 1e-9));
      expect(observation.torsoInclinationDegrees, closeTo(0, 1e-9));
    });

    test('extracts a complete squat from one selected side profile', () {
      final observation = extractor.extractSquat(
        _pose(<PoseLandmarkType, (double, double)>{
          PoseLandmarkType.leftShoulder: (-1, 0),
          PoseLandmarkType.leftHip: (-1, 2),
          PoseLandmarkType.leftKnee: (0, 2),
          PoseLandmarkType.leftAnkle: (0, 3),
          PoseLandmarkType.rightShoulder: (1, 0),
          PoseLandmarkType.rightHip: (1, 2),
          PoseLandmarkType.rightKnee: (1, 4),
          PoseLandmarkType.rightAnkle: (1, 6),
        }),
        side: AssessmentSide.left,
      );

      expect(observation.isComplete, isTrue);
      expect(observation.leftKneeAngleDegrees, closeTo(90, 1e-9));
      expect(observation.rightKneeAngleDegrees, isNull);
      expect(observation.hipDepthRatio, closeTo(0, 1e-9));
      expect(observation.torsoInclinationDegrees, closeTo(0, 1e-9));
    });

    test(
      'keeps squat incomplete while preserving available partial measurements',
      () {
        final observation = extractor.extractSquat(
          _pose(<PoseLandmarkType, (double, double)>{
            PoseLandmarkType.leftHip: (-1, 1),
            PoseLandmarkType.leftKnee: (-1, 2),
            PoseLandmarkType.leftAnkle: (-1, 3),
          }),
        );

        expect(observation.isComplete, isFalse);
        expect(observation.leftKneeAngleDegrees, closeTo(180, 1e-9));
        expect(observation.rightKneeAngleDegrees, isNull);
        expect(observation.hipDepthRatio, closeTo(1, 1e-9));
        expect(observation.torsoInclinationDegrees, isNull);
      },
    );

    test('normalizes balance sway coordinates by torso length', () {
      final observation = extractor.extractBalance(
        _pose(<PoseLandmarkType, (double, double)>{
          PoseLandmarkType.leftShoulder: (0, 0),
          PoseLandmarkType.rightShoulder: (2, 0),
          PoseLandmarkType.leftHip: (0, 2),
          PoseLandmarkType.rightHip: (2, 2),
          PoseLandmarkType.leftAnkle: (0, 5),
          PoseLandmarkType.rightAnkle: (2, 3),
        }),
        side: AssessmentSide.left,
        capturedAt: DateTime.utc(2026),
      );

      expect(observation.shoulderCenterXNormalized, closeTo(0.5, 1e-9));
      expect(observation.hipCenterXNormalized, closeTo(0.5, 1e-9));
      expect(observation.raisedFootClearanceRatio, closeTo(1.0, 1e-9));
    });

    test('balance foot clearance follows the selected stance side', () {
      final pose = _pose(<PoseLandmarkType, (double, double)>{
        PoseLandmarkType.leftShoulder: (0, 0),
        PoseLandmarkType.rightShoulder: (2, 0),
        PoseLandmarkType.leftHip: (0, 2),
        PoseLandmarkType.rightHip: (2, 2),
        PoseLandmarkType.leftAnkle: (0, 5),
        PoseLandmarkType.rightAnkle: (2, 3),
      });

      final left = extractor.extractBalance(
        pose,
        side: AssessmentSide.left,
        capturedAt: DateTime.utc(2026),
      );
      final right = extractor.extractBalance(
        pose,
        side: AssessmentSide.right,
        capturedAt: DateTime.utc(2026),
      );

      expect(left.raisedFootClearanceRatio, greaterThan(0));
      expect(right.raisedFootClearanceRatio, lessThan(0));
    });

    test('extracts shoulder elevation from torso and upper-arm segments', () {
      final observation = extractor.extractShoulderMobility(
        _pose(<PoseLandmarkType, (double, double)>{
          PoseLandmarkType.leftShoulder: (-1, 0),
          PoseLandmarkType.rightShoulder: (1, 0),
          PoseLandmarkType.leftHip: (-1, 2),
          PoseLandmarkType.rightHip: (1, 2),
          PoseLandmarkType.leftElbow: (-1, -2),
          PoseLandmarkType.rightElbow: (1, 2),
        }),
      );

      expect(observation.leftElevationDegrees, closeTo(180, 1e-9));
      expect(observation.rightElevationDegrees, closeTo(0, 1e-9));
      expect(observation.torsoInclinationDegrees, closeTo(0, 1e-9));
    });

    test('shoulder mobility keeps a missing side as null', () {
      final observation = extractor.extractShoulderMobility(
        _pose(<PoseLandmarkType, (double, double)>{
          PoseLandmarkType.leftHip: (-1, 2),
          PoseLandmarkType.leftShoulder: (-1, 0),
          PoseLandmarkType.leftElbow: (-1, -2),
        }),
      );

      expect(observation.leftElevationDegrees, closeTo(180, 1e-9));
      expect(observation.rightElevationDegrees, isNull);
      expect(observation.torsoInclinationDegrees, isNull);
    });
  });
}

Pose _pose(Map<PoseLandmarkType, (double, double)> coordinates) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final entry in coordinates.entries)
        entry.key: PoseLandmark(
          type: entry.key,
          x: entry.value.$1,
          y: entry.value.$2,
          z: 0,
          likelihood: 1,
        ),
    },
  );
}
