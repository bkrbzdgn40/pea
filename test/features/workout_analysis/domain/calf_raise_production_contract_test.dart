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
  final definition = catalog.definitionFor(ExerciseType.calfRaise);

  group('Calf Raise production contract', () {
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

    test('accepts a natural side-view standing setup as neutral', () {
      final metrics = extractor.extract(
        _calfRaisePose(primaryAngle: 115, kneeAngle: 175),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: definition.analysisRangeRepContract,
      );
      final sideMetrics = metrics.leftRangeRepMetrics;

      expect(config.thresholdNeutral, 125.0);
      expect(config.thresholdActive, 140.0);
      expect(config.thresholdPeak, 155.0);
      expect(config.targetMaxAngle, 165.0);
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        15.0,
      );
      expect(sideMetrics.primaryAngle, closeTo(115.0, 0.001));
      expect(sideMetrics.formMetric, closeTo(175.0, 0.001));
      expect(sideMetrics.primaryAngle, lessThan(config.thresholdNeutral));

      _confirm(engine, clock, sideMetrics.primaryAngle);

      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 0);
    });

    test('counts one controlled heel-raise lifecycle', () {
      _confirm(engine, clock, 115);
      _confirm(engine, clock, 145);
      _confirm(engine, clock, 165);
      _confirm(engine, clock, 145);
      final completed = _confirm(engine, clock, 115);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.completedRepDetectionData, isNotNull);
      expect(completed.completedRepDetectionData!.primaryRom, 20.0);
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

Pose _calfRaisePose({required double primaryAngle, required double kneeAngle}) {
  final footDirection = (-90.0 + primaryAngle) * math.pi / 180.0;
  final hipDirection = (-90.0 - (180.0 - kneeAngle)) * math.pi / 180.0;
  const ankle = math.Point<double>(0, 0);
  const knee = math.Point<double>(0, -1);
  final footIndex = math.Point<double>(
    math.cos(footDirection),
    math.sin(footDirection),
  );
  final hip = math.Point<double>(
    knee.x + math.cos(hipDirection),
    knee.y + math.sin(hipDirection),
  );

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
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
      PoseLandmarkType.leftFootIndex: buildLandmark(
        PoseLandmarkType.leftFootIndex,
        footIndex.x,
        footIndex.y,
      ),
    },
  );
}
