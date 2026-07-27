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
  final definition = catalog.definitionFor(ExerciseType.goodMorning);

  group('Good Morning production contract', () {
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

    test('extracts hip hinge and knee-form metrics from a side-view pose', () {
      final metrics = extractor.extract(
        _goodMorningPose(hipAngle: 170, kneeAngle: 165),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: definition.analysisRangeRepContract,
      );
      final left = metrics.leftRangeRepMetrics;

      expect(left.hasPrimaryAngle, isTrue);
      expect(left.hasFormMetric, isTrue);
      expect(left.primaryAngle, closeTo(170.0, 0.001));
      expect(left.formMetric, closeTo(165.0, 0.001));
    });

    test('counts one controlled neutral-peak-neutral hip-hinge cycle', () {
      _confirm(engine, clock, 170);
      _confirm(engine, clock, 145);
      _confirm(engine, clock, 110);
      _confirm(engine, clock, 150);
      final completed = _confirm(engine, clock, 170);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.didCompleteRep, isTrue);
      expect(completed.completedRepDetectionData?.startAngle, 145.0);
      expect(
        completed.completedRepDetectionData?.primaryRom,
        closeTo(35.0, 0.001),
      );
    });

    test('rejects a shallow hinge that never reaches the peak threshold', () {
      _confirm(engine, clock, 170);
      _confirm(engine, clock, 145);
      _confirm(engine, clock, 130);
      _confirm(engine, clock, 155);
      _confirm(engine, clock, 170);

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });
  });
}

RangeRepEngineFrameResult _confirm(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 220));
  final result = engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 220));
  return result;
}

Pose _goodMorningPose({required double hipAngle, required double kneeAngle}) {
  const hip = math.Point<double>(0, 0);
  const knee = math.Point<double>(0, 1);
  final shoulderDirection = (90.0 + hipAngle) * math.pi / 180.0;
  final ankleDirection = (-90.0 + kneeAngle) * math.pi / 180.0;
  final shoulder = math.Point<double>(
    math.cos(shoulderDirection),
    math.sin(shoulderDirection),
  );
  final ankle = math.Point<double>(
    knee.x + math.cos(ankleDirection),
    knee.y + math.sin(ankleDirection),
  );

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
