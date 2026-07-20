import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/plank_shoulder_elbow_offset_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = PlankShoulderElbowOffsetMeasurement();
  const extractor = ExerciseMetricsExtractor();

  group('PlankShoulderElbowOffsetMeasurement', () {
    test('returns zero when shoulder and elbow are vertically stacked', () {
      final value = measurement.measure(
        _pose(
          _shoulderElbowLandmarks(
            side: HoldSide.left,
            shoulderX: 0,
            shoulderY: 0,
            elbowX: 0,
            elbowY: 2,
          ),
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.0, 0.001));
    });

    test('normalizes horizontal offset by shoulder-elbow length', () {
      final value = measurement.measure(
        _pose(
          _shoulderElbowLandmarks(
            side: HoldSide.left,
            shoulderX: 0,
            shoulderY: 0,
            elbowX: 3,
            elbowY: 4,
          ),
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.6, 0.001));
    });

    test('mirrors the measurement to the selected right side', () {
      final pose = _pose(
        _shoulderElbowLandmarks(
          side: HoldSide.right,
          shoulderX: 4,
          shoulderY: 0,
          elbowX: 3,
          elbowY: 2,
        ),
      );

      expect(
        measurement.measure(pose, side: HoldSide.right),
        closeTo(1 / math.sqrt(5), 0.001),
      );
      expect(measurement.measure(pose, side: HoldSide.left), isNull);
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measure(
        _pose(
          _shoulderElbowLandmarks(
            side: HoldSide.left,
            shoulderX: 0,
            shoulderY: 0,
            elbowX: 1,
            elbowY: 2,
          ),
        ),
        side: HoldSide.left,
      );
      final scaled = measurement.measure(
        _pose(
          _shoulderElbowLandmarks(
            side: HoldSide.left,
            shoulderX: 0,
            shoulderY: 0,
            elbowX: 4,
            elbowY: 8,
          ),
        ),
        side: HoldSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null for missing landmarks and a degenerate segment', () {
      final missingElbow = _pose(<PoseLandmark>[
        buildLandmark(PoseLandmarkType.leftShoulder, 0, 0, likelihood: 0.95),
      ]);
      final zeroLength = _pose(
        _shoulderElbowLandmarks(
          side: HoldSide.left,
          shoulderX: 1,
          shoulderY: 1,
          elbowX: 1,
          elbowY: 1,
        ),
      );

      expect(measurement.measure(missingElbow, side: HoldSide.left), isNull);
      expect(measurement.measure(zeroLength, side: HoldSide.left), isNull);
    });
  });

  test(
    'plank contract moves stacking technique semantics off support angle',
    () {
      final contract = HoldContracts.plankFamily;

      expect(contract.requiredSignals, contains(HoldSignal.support));
      expect(
        contract.rolesForSignal(HoldSignal.support),
        const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.validation,
        },
      );
      expect(contract.signalsForRole(AnalysisSignalRole.technique), isEmpty);
    },
  );

  test(
    'generic hold transport stays legacy while plank owns offset measurement',
    () {
      final pose = _plankPose();
      final metrics = extractor.extract(
        pose,
        buildPlankConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        metrics.holdSignalValues.valueFor(HoldSignal.support),
        closeTo(90, 0.001),
      );
      expect(
        metrics.holdSignalValues.signals,
        everyElement(isIn(HoldContracts.plankFamily.requiredSignals)),
      );
      expect(
        measurement.measure(pose, side: HoldSide.left),
        closeTo(0.0, 0.001),
      );
    },
  );
}

Pose _pose(List<PoseLandmark> landmarks) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    },
  );
}

Pose _plankPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        -1,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftElbow: buildLandmark(
        PoseLandmarkType.leftElbow,
        -1,
        1,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftWrist: buildLandmark(
        PoseLandmarkType.leftWrist,
        0,
        1,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        0,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftKnee: buildLandmark(
        PoseLandmarkType.leftKnee,
        0.5,
        0,
        likelihood: 0.95,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        1,
        0,
        likelihood: 0.95,
      ),
    },
  );
}

List<PoseLandmark> _shoulderElbowLandmarks({
  required HoldSide side,
  required double shoulderX,
  required double shoulderY,
  required double elbowX,
  required double elbowY,
}) {
  final isLeft = side == HoldSide.left;
  final shoulderType = isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final elbowType = isLeft
      ? PoseLandmarkType.leftElbow
      : PoseLandmarkType.rightElbow;

  return <PoseLandmark>[
    buildLandmark(shoulderType, shoulderX, shoulderY, likelihood: 0.95),
    buildLandmark(elbowType, elbowX, elbowY, likelihood: 0.95),
  ];
}
