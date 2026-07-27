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
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

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

    test('accepts the observed hips-down device range as neutral', () {
      final metrics = extractor.extract(
        _gluteBridgePose(primaryAngle: 142),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: definition.analysisRangeRepContract,
      );
      final primaryMetric = metrics.leftRangeRepMetrics.primaryAngle;

      expect(config.thresholdNeutral, 148.0);
      expect(config.thresholdActive, 154.0);
      expect(config.thresholdPeak, 164.0);
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        10.0,
      );
      expect(
        definition.analysisRangeRepContract.initialNeutralConfirmationDuration,
        const Duration(milliseconds: 600),
      );
      expect(primaryMetric, closeTo(142.0, 0.001));
      expect(primaryMetric, lessThan(config.thresholdNeutral));

      _confirmInitialNeutral(engine, clock, primaryMetric);

      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('uses a bridge-specific toward-peak tempo tolerance', () {
      final validationConfig = definition.analysisRangeRepValidationConfig;
      final phaseQualityConfig = config.rangeRepPhaseQuality;
      final policy = RangeRepValidationPolicy(config: validationConfig);

      expect(validationConfig.minDescentMillis, 180);
      expect(phaseQualityConfig, isNotNull);
      expect(phaseQualityConfig!.minDescendingMillis, 180);

      final normalTempo = policy.evaluate(
        _completedBridgeSummary(
          towardPeakDuration: const Duration(milliseconds: 200),
        ),
      );
      final abruptTempo = policy.evaluate(
        _completedBridgeSummary(
          towardPeakDuration: const Duration(milliseconds: 160),
        ),
      );

      expect(normalTempo.status, RangeRepValidationStatus.valid);
      expect(
        normalTempo.reasons,
        isNot(contains(RangeRepValidationReason.excessiveDescentSpeed)),
      );
      expect(abruptTempo.status, RangeRepValidationStatus.lowConfidence);
      expect(
        abruptTempo.reasons,
        contains(RangeRepValidationReason.excessiveDescentSpeed),
      );
    });

    test('does not arm during a brief get-down transition', () {
      engine.updateDetectionFrame(primaryMetric: 142);
      clock.advance(const Duration(milliseconds: 120));
      engine.updateDetectionFrame(primaryMetric: 160);
      clock.advance(const Duration(milliseconds: 120));
      engine.updateDetectionFrame(primaryMetric: 170);
      clock.advance(const Duration(milliseconds: 120));
      engine.updateDetectionFrame(primaryMetric: 142);

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'AWAITING_NEUTRAL');
    });

    test('counts a controlled bridge after stable neutral acquisition', () {
      _confirmInitialNeutral(engine, clock, 142);
      _confirm(engine, clock, 160);
      _confirm(engine, clock, 168);
      _confirm(engine, clock, 155);
      final completed = _confirm(engine, clock, 142);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.completedRepDetectionData, isNotNull);
      expect(
        completed.completedRepDetectionData!.primaryRom,
        closeTo(26.0, 0.001),
      );
    });
  });
}

RangeRepRepSummary _completedBridgeSummary({
  required Duration towardPeakDuration,
}) {
  return RangeRepRepSummary(
    repIndex: 1,
    minAngle: 142,
    worstFormMetric: 0,
    descentDuration: towardPeakDuration,
    ascentDuration: const Duration(milliseconds: 600),
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    startAngle: 142,
    primaryRom: 26,
    analysisKindLabel: 'rangeRep',
  );
}

void _confirmInitialNeutral(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 600));
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 20));
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
