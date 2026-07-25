import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  const extractor = ExerciseMetricsExtractor();
  final definition = catalog.definitionFor(ExerciseType.gluteBridge);

  group('Glute Bridge production contract', () {
    late TestFakeClock clock;
    late ExerciseConfig config;
    late RangeRepAnalysisEngine engine;

    setUp(() {
      clock = TestFakeClock();
      config = loadExerciseConfig(definition.analysisConfigAssetPath);
      engine = factory.createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      );
    });

    test('accepts the reference hips-down setup as neutral', () {
      final metrics = extractor.extract(
        _gluteBridgePose(primaryAngle: 125),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: definition.analysisRangeRepContract,
      );
      final primaryMetric = metrics.leftRangeRepMetrics.primaryAngle;

      expect(config.thresholdNeutral, 135.0);
      expect(config.thresholdActive, 145.0);
      expect(config.thresholdPeak, 155.0);
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        10.0,
      );
      expect(primaryMetric, closeTo(125.0, 0.001));
      expect(primaryMetric, lessThan(config.thresholdNeutral));

      _confirm(engine, clock, primaryMetric);

      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('counts a controlled bridge from the calibrated neutral setup', () {
      _confirm(engine, clock, 125);
      _confirm(engine, clock, 150);
      _confirm(engine, clock, 160);
      _confirm(engine, clock, 146);
      final completed = _confirm(engine, clock, 125);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.completedRepDetectionData, isNotNull);
      expect(completed.completedRepDetectionData!.primaryRom, 10.0);
    });
  });
}

RangeRepEngineFrameResult _confirm(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 120));
  final result = engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 20));
  return result;
}

Pose _gluteBridgePose({required double primaryAngle}) {
  final radians = primaryAngle * math.pi / 180.0;
  const hip = math.Point<double>(0, 0);
  const shoulder = math.Point<double>(1, 0);
  final knee = math.Point<double>(math.cos(radians), math.sin(radians));
  final ankle = math.Point<double>(knee.x, knee.y + 1);

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        shoulder.x,
        shoulder.y,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        hip.x,
        hip.y,
      ),
      PoseLandmarkType.leftKnee: buildLandmark(
        PoseLandmarkType.leftKnee,
        knee.x,
        knee.y,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        ankle.x,
        ankle.y,
      ),
    },
  );
}
