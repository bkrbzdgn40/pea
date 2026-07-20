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
      final value = measurement.measureLandmarks(
        _shoulderElbowLandmarks(
          side: HoldSide.left,
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 0,
          elbowY: 2,
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.0, 0.001));
    });

    test('normalizes horizontal offset by shoulder-elbow length', () {
      final value = measurement.measureLandmarks(
        _shoulderElbowLandmarks(
          side: HoldSide.left,
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 3,
          elbowY: 4,
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.6, 0.001));
    });

    test('mirrors the measurement to the selected right side', () {
      final landmarks = _shoulderElbowLandmarks(
        side: HoldSide.right,
        shoulderX: 4,
        shoulderY: 0,
        elbowX: 3,
        elbowY: 2,
      );

      expect(
        measurement.measureLandmarks(landmarks, side: HoldSide.right),
        closeTo(1 / 5.0.sqrt(), 0.001),
      );
      expect(
        measurement.measureLandmarks(landmarks, side: HoldSide.left),
        isNull,
      );
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measureLandmarks(
        _shoulderElbowLandmarks(
          side: HoldSide.left,
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 1,
          elbowY: 2,
        ),
        side: HoldSide.left,
      );
      final scaled = measurement.measureLandmarks(
        _shoulderElbowLandmarks(
          side: HoldSide.left,
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 4,
          elbowY: 8,
        ),
        side: HoldSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null for missing landmarks and a degenerate segment', () {
      final missingElbow = <PoseLandmark>[
        buildLandmark(PoseLandmarkType.leftShoulder, 0, 0, likelihood: 0.95),
      ];
      final zeroLength = _shoulderElbowLandmarks(
        side: HoldSide.left,
        shoulderX: 1,
        shoulderY: 1,
        elbowX: 1,
        elbowY: 1,
      );

      expect(
        measurement.measureLandmarks(missingElbow, side: HoldSide.left),
        isNull,
      );
      expect(
        measurement.measureLandmarks(zeroLength, side: HoldSide.left),
        isNull,
      );
    });
  });

  test('plank contract moves stacking technique semantics off support angle', () {
    final contract = HoldContracts.plankFamily;

    expect(contract.requiredSignals, contains(HoldSignal.support));
    expect(
      contract.rolesForSignal(HoldSignal.support),
      const <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
    );
    expect(
      contract.rolesForSignal(HoldSignal.shoulderElbowOffset),
      const <AnalysisSignalRole>{AnalysisSignalRole.technique},
    );
  });

  test('extractor wires shoulder-elbow offset only for explicit plank family', () {
    final pose = _plankPose();
    final plankMetrics = extractor.extract(
      pose,
      buildPlankConfig(),
      engineKind: EngineKind.hold,
      holdContract: HoldContracts.plankFamily,
      holdSide: HoldSide.left,
    );

    expect(
      plankMetrics.holdSignalValues.valueFor(HoldSignal.support),
      closeTo(90.0, 0.001),
    );
    expect(
      plankMetrics.holdSignalValues.valueFor(HoldSignal.shoulderElbowOffset),
      closeTo(0.0, 0.001),
    );

    final nonPlankContract = HoldContract(
      family: HoldAnalysisFamily.hollowHold,
      requiredSignals: const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
      },
      supportedSignals: const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
        HoldSignal.shoulderElbowOffset,
      },
      signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
        HoldSignal.alignment: <AnalysisSignalRole>{
          AnalysisSignalRole.validation,
        },
        HoldSignal.support: <AnalysisSignalRole>{
          AnalysisSignalRole.validation,
        },
        HoldSignal.extension: <AnalysisSignalRole>{
          AnalysisSignalRole.validation,
        },
        HoldSignal.shoulderElbowOffset: <AnalysisSignalRole>{
          AnalysisSignalRole.technique,
        },
      },
    );
    final nonPlankMetrics = extractor.extract(
      pose,
      buildPlankConfig(),
      engineKind: EngineKind.hold,
      holdContract: nonPlankContract,
      holdSide: HoldSide.left,
    );

    expect(
      nonPlankMetrics.holdSignalValues.hasValue(HoldSignal.support),
      isTrue,
    );
    expect(
      nonPlankMetrics.holdSignalValues.hasValue(
        HoldSignal.shoulderElbowOffset,
      ),
      isFalse,
    );
  });
}

Pose _plankPose() {
  final landmarks = <PoseLandmarkType, PoseLandmark>{
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
  };
  return Pose(landmarks: landmarks);
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

extension on double {
  double sqrt() => 2.23606797749979;
}
