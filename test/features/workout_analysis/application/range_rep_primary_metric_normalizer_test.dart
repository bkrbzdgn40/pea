import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_primary_metric_normalizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const extractor = ExerciseMetricsExtractor();
  final sitUpConfig = loadExerciseConfig('assets/config/exercises/sit_up.json');

  test('joint-angle range reps bypass image-plane normalization', () {
    final squatConfig = buildSquatConfig();
    final pose = buildSquatPose(angle: 170);
    final metrics = extractor.extract(
      pose,
      squatConfig,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.squat,
    );
    final normalizer = RangeRepPrimaryMetricNormalizer(
      config: squatConfig,
      rangeRepContract: RangeRepContracts.squat,
    );

    final normalized = normalizer.normalize(pose: pose, metrics: metrics);

    expect(normalized, same(metrics));
  });

  test(
    'Sit-up keeps the existing engine metric scale from neutral to peak',
    () {
      final normalizer = RangeRepPrimaryMetricNormalizer(
        config: sitUpConfig,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      final normalizedValues = <double>[
        for (final primaryAngle in <double>[125, 108, 68, 92, 121])
          _normalizeSitUp(
            extractor: extractor,
            normalizer: normalizer,
            config: sitUpConfig,
            pose: buildSitUpPose(primaryAngle: primaryAngle),
          ).leftRangeRepMetrics.primaryAngle,
      ];

      _expectSequenceCloseTo(normalizedValues, const <double>[
        125,
        108,
        68,
        92,
        121,
      ]);
    },
  );

  test('Sit-up normalized movement is invariant to rigid image rotation', () {
    final unrotated = _normalizedSitUpSequence(
      extractor: extractor,
      config: sitUpConfig,
      rotationDegrees: 0,
    );
    final rotatedClockwise = _normalizedSitUpSequence(
      extractor: extractor,
      config: sitUpConfig,
      rotationDegrees: 90,
    );
    final rotatedCounterClockwise = _normalizedSitUpSequence(
      extractor: extractor,
      config: sitUpConfig,
      rotationDegrees: -90,
    );

    _expectSequenceCloseTo(rotatedClockwise, unrotated);
    _expectSequenceCloseTo(rotatedCounterClockwise, unrotated);
  });

  test('Sit-up normalizes mirrored left and right torso movement equally', () {
    final normalizer = RangeRepPrimaryMetricNormalizer(
      config: sitUpConfig,
      rangeRepContract: RangeRepContracts.sitUp,
    );

    _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: buildSitUpPose(primaryAngle: 125),
    );
    final normalized = _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: buildSitUpPose(primaryAngle: 68),
    );

    expect(normalized.leftRangeRepMetrics.primaryAngle, closeTo(68, 0.001));
    expect(normalized.rightRangeRepMetrics.primaryAngle, closeTo(68, 0.001));
    expect(
      normalized.leftRangeRepMetrics.formSignals?.depthMetric,
      closeTo(68, 0.001),
    );
    expect(
      normalized.rightRangeRepMetrics.formSignals?.depthMetric,
      closeTo(68, 0.001),
    );
  });

  test('an orientation discontinuity re-establishes a neutral baseline', () {
    final normalizer = RangeRepPrimaryMetricNormalizer(
      config: sitUpConfig,
      rangeRepContract: RangeRepContracts.sitUp,
    );
    final neutralPose = buildSitUpPose(primaryAngle: 125);

    _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: neutralPose,
    );
    final normalized = _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: _rotatePose(neutralPose, 90),
    );

    expect(normalized.leftRangeRepMetrics.primaryAngle, closeTo(125, 0.001));
    expect(normalized.rightRangeRepMetrics.primaryAngle, closeTo(125, 0.001));
  });

  test('reset discards the previous Sit-up orientation baseline', () {
    final normalizer = RangeRepPrimaryMetricNormalizer(
      config: sitUpConfig,
      rangeRepContract: RangeRepContracts.sitUp,
    );

    _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: buildSitUpPose(primaryAngle: 125),
    );
    final active = _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: buildSitUpPose(primaryAngle: 68),
    );
    normalizer.reset();
    final reacquired = _normalizeSitUp(
      extractor: extractor,
      normalizer: normalizer,
      config: sitUpConfig,
      pose: buildSitUpPose(primaryAngle: 68),
    );

    expect(active.leftRangeRepMetrics.primaryAngle, closeTo(68, 0.001));
    expect(reacquired.leftRangeRepMetrics.primaryAngle, closeTo(125, 0.001));
  });
}

void _expectSequenceCloseTo(List<double> actual, List<double> expected) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(actual[index], closeTo(expected[index], 0.001));
  }
}

List<double> _normalizedSitUpSequence({
  required ExerciseMetricsExtractor extractor,
  required ExerciseConfig config,
  required double rotationDegrees,
}) {
  final normalizer = RangeRepPrimaryMetricNormalizer(
    config: config,
    rangeRepContract: RangeRepContracts.sitUp,
  );

  return <double>[
    for (final primaryAngle in <double>[125, 108, 68, 92, 121])
      _normalizeSitUp(
        extractor: extractor,
        normalizer: normalizer,
        config: config,
        pose: _rotatePose(
          buildSitUpPose(primaryAngle: primaryAngle),
          rotationDegrees,
        ),
      ).leftRangeRepMetrics.primaryAngle,
  ];
}

ExerciseMetrics _normalizeSitUp({
  required ExerciseMetricsExtractor extractor,
  required RangeRepPrimaryMetricNormalizer normalizer,
  required ExerciseConfig config,
  required Pose pose,
}) {
  final metrics = extractor.extract(
    pose,
    config,
    engineKind: EngineKind.rangeRep,
    rangeRepContract: RangeRepContracts.sitUp,
  );
  return normalizer.normalize(pose: pose, metrics: metrics);
}

Pose _rotatePose(Pose pose, double degrees) {
  if (degrees == 0) {
    return pose;
  }

  final radians = degrees * math.pi / 180.0;
  final cosine = math.cos(radians);
  final sine = math.sin(radians);

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final entry in pose.landmarks.entries)
        entry.key: PoseLandmark(
          type: entry.value.type,
          x: entry.value.x * cosine - entry.value.y * sine,
          y: entry.value.x * sine + entry.value.y * cosine,
          z: entry.value.z,
          likelihood: entry.value.likelihood,
        ),
    },
  );
}
