import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  test('production coordinator emits threshold-free squat torso drift observations', () {
    final clock = _TestClock();
    final config = buildSquatConfig();
    final engine = const AnalysisEngineFactory().createRangeRep(
      config: config,
      rangeRepContract: RangeRepContracts.squat,
      now: clock.now,
    );
    final coordinator = DefaultRangeRepCoordinator(
      engine: engine,
      config: config,
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: const RangeRepValidationConfig(
        minAcceptableRomAngle: 110,
        minDescentMillis: 300,
        minAscentMillis: 250,
        allowLowConfidenceOnCoverageLoss: true,
      ),
    );

    _pumpUntilPhase(
      coordinator,
      clock,
      angle: 170,
      torsoInclination: 10,
      expectedPhase: 'NEUTRAL',
    );
    _pumpUntilPhase(
      coordinator,
      clock,
      angle: 140,
      torsoInclination: 20,
      expectedPhase: 'DESCENDING',
    );
    _pumpUntilPhase(
      coordinator,
      clock,
      angle: 90,
      torsoInclination: 35,
      expectedPhase: 'PEAK',
    );
    _pumpUntilPhase(
      coordinator,
      clock,
      angle: 110,
      torsoInclination: 25,
      expectedPhase: 'ASCENDING',
    );
    _pumpUntilPhase(
      coordinator,
      clock,
      angle: 170,
      torsoInclination: 10,
      expectedPhase: 'NEUTRAL',
    );

    expect(coordinator.techniqueObservations, hasLength(2));
    expect(
      coordinator.techniqueObservations.map((observation) => observation.type),
      everyElement(RangeRepTechniqueObservationType.torsoDrift),
    );
    expect(coordinator.techniqueObservations[0].deltaValue, closeTo(15, 0.001));
    expect(coordinator.techniqueObservations[1].deltaValue, closeTo(-10, 0.001));
    expect(
      coordinator.techniqueObservations.map((observation) => observation.severity),
      everyElement(RangeRepTechniqueSeverity.info),
    );
  });
}

void _pumpUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  required double torsoInclination,
  required String expectedPhase,
}) {
  for (var i = 0; i < 20; i++) {
    final metrics = const ExerciseMetricsExtractor().extract(
      _buildSquatPose(angle: angle, torsoInclination: torsoInclination),
      buildSquatConfig(),
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.squat,
    );
    final result = coordinator.processFrame(
      metrics: metrics,
      now: clock.now(),
      isAcceptedPoseFrame: true,
      didBecomeStableTracking: false,
      qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
      preferredRangeRepSide: RangeRepSide.left,
    );
    clock.advance(const Duration(milliseconds: 120));
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return;
    }
  }

  fail('Did not reach phase $expectedPhase.');
}

Pose _buildSquatPose({
  required double angle,
  required double torsoInclination,
}) {
  final pose = buildSquatPose(angle: angle);
  final landmarks = Map<PoseLandmarkType, PoseLandmark>.from(pose.landmarks);
  final radians = torsoInclination * math.pi / 180;
  landmarks[PoseLandmarkType.leftShoulder] = buildLandmark(
    PoseLandmarkType.leftShoulder,
    math.sin(radians),
    1 - math.cos(radians),
    likelihood: 0.95,
  );
  return Pose(landmarks: landmarks);
}

class _TestClock {
  DateTime _now = DateTime.utc(2030, 1, 1, 12);

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
