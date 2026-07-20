import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/biceps_torso_inclination_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hollow_hold_limb_elevation_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/plank_hip_deviation_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/plank_shoulder_elbow_offset_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/biceps_torso_swing_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hollow_hold_posture_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_scorer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hollow_hold_variation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/plank_technique_analyzer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('Analysis Core v2 roadmap completion contracts', () {
    test('R23 plank hip deviation is normalized and scale invariant', () {
      const measurement = PlankHipDeviationMeasurement();
      final original = measurement.measure(
        _plankPose(scale: 1),
        side: HoldSide.left,
      );
      final scaled = measurement.measure(
        _plankPose(scale: 4),
        side: HoldSide.left,
      );

      expect(original, closeTo(0.5, 0.001));
      expect(scaled, closeTo(original!, 0.001));
    });

    test('R24 shoulder-elbow offset uses a physical normalized offset', () {
      const measurement = PlankShoulderElbowOffsetMeasurement();
      final value = measurement.measure(
        _plankPose(scale: 2),
        side: HoldSide.left,
      );

      expect(value, closeTo(1.0, 0.001));
    });

    test('R25 severity is separate from hold validity and pose acceptance', () {
      const analyzer = PlankTechniqueAnalyzer();
      final assessment = analyzer.assess(
        hipDeviation: 0.2,
        shoulderElbowOffset: 0.1,
        kneeExtensionAngle: 150,
        legacySignalValidity: HoldSignalValidity(
          values: <HoldSignal, bool>{
            HoldSignal.alignment: false,
            HoldSignal.support: true,
            HoldSignal.extension: true,
          },
        ),
      );

      expect(assessment.observations, hasLength(3));
      expect(
        assessment.observations.map((item) => item.severity),
        everyElement(HoldTechniqueSeverity.info),
      );
      expect(
        assessment.primaryPlankObservation?.type,
        HoldTechniqueObservationType.plankHipDeviation,
      );
      expect(assessment.observations.first.legacyGatePassed, isFalse);
      expect(
        HoldContracts.plankFamily.signalsForRole(AnalysisSignalRole.technique),
        isEmpty,
      );
    });

    test('R26 biceps torso swing is a neutral-to-peak delta observation', () {
      final tracker = BicepsTorsoSwingTracker()
        ..recordNeutral(8)
        ..recordPeak(23);

      final observation = tracker.buildObservation();
      expect(observation?.type, RangeRepTechniqueObservationType.torsoSwing);
      expect(observation?.referencePhase, RangeRepTechniquePhase.neutral);
      expect(observation?.phase, RangeRepTechniquePhase.peak);
      expect(observation?.deltaValue, closeTo(15, 0.001));
    });

    test('R26 torso inclination measurement supports bilateral input', () {
      const measurement = BicepsTorsoInclinationMeasurement();
      final value = measurement.measureBilateral(_bicepsPose());

      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(90));
    });

    test('R27 validation can use explicit start-to-peak ROM delta', () {
      const policy = RangeRepValidationPolicy(
        config: RangeRepValidationConfig(
          minAcceptableRomDelta: 45,
          minDescentMillis: 0,
          minAscentMillis: 0,
        ),
      );
      final valid = policy.evaluate(_summary(primaryRom: 50));
      final invalid = policy.evaluate(_summary(primaryRom: 40));

      expect(valid.status.debugLabel, 'valid');
      expect(invalid.status.debugLabel, 'invalid');
    });

    test('R29 ROM scoring saturates once target ROM is reached', () {
      const scorer = LegacyRangeRepScorer();
      final below = scorer.calculateSaturatingRomScore(
        achievedRom: 30,
        minimumAcceptableRom: 40,
        targetRom: 60,
      );
      final target = scorer.calculateSaturatingRomScore(
        achievedRom: 60,
        minimumAcceptableRom: 40,
        targetRom: 60,
      );
      final beyond = scorer.calculateSaturatingRomScore(
        achievedRom: 90,
        minimumAcceptableRom: 40,
        targetRom: 60,
      );

      expect(below.region, RangeRepRomRegion.insufficient);
      expect(target.region, RangeRepRomRegion.targetReached);
      expect(target.score, 100);
      expect(beyond.score, 100);
    });

    test('R32 WorkoutRep round-trips Core v2 analysis persistence fields', () {
      const rep = WorkoutRep(
        repIndex: 1,
        exerciseType: 'bicepsCurl',
        analysisKind: 'rangeRep',
        validationStatus: 'valid',
        confidence: 0.92,
        primaryRom: 62,
        eccentricMillis: 700,
        concentricMillis: 600,
        techniqueObservations: <Map<String, Object?>>[
          <String, Object?>{
            'type': 'torsoSwing',
            'code': 'biceps_torso_swing_observed',
            'severity': 'info',
          },
        ],
        selectedSide: 'bilateral',
        coverageQuality: 0.95,
      );

      final restored = WorkoutRep.fromMap(rep.toMap());
      expect(restored.confidence, 0.92);
      expect(restored.primaryRom, 62);
      expect(restored.eccentricMillis, 700);
      expect(restored.concentricMillis, 600);
      expect(restored.techniqueObservations, hasLength(1));
      expect(restored.selectedSide, 'bilateral');
      expect(restored.coverageQuality, 0.95);
    });

    test('R33-R35 variation contracts own Hollow Hold validation needs', () {
      const config = HollowHoldPostureConfig(
        activePostureMaxAngle: 170,
        compressionEntryMaxAngle: 165,
        compressionSustainMaxAngle: 169,
        armExtensionMinAngle: 135,
        kneeExtensionMinAngle: 165,
        breakGraceDuration: Duration(milliseconds: 300),
      );
      final tuck = HollowHoldPosturePolicy(
        config: config,
        variationContract: HollowHoldVariationContracts.tuck,
      );
      final straightLeg = HollowHoldPosturePolicy(
        config: config,
        variationContract: HollowHoldVariationContracts.straightLeg,
      );
      final overhead = HollowHoldPosturePolicy(
        config: config,
        variationContract: HollowHoldVariationContracts.straightLegOverhead,
      );
      expect(
        HoldContracts.hollowHoldForVariation(
          HollowHoldVariation.tuck,
        ).requiredSignals,
        const <HoldSignal>{HoldSignal.compression},
      );
      expect(
        HoldContracts.hollowHoldForVariation(
          HollowHoldVariation.straightLeg,
        ).requiredSignals,
        const <HoldSignal>{HoldSignal.compression, HoldSignal.kneeExtension},
      );

      final signals = HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.compression: 160,
          HoldSignal.armExtension: 100,
          HoldSignal.kneeExtension: 100,
        },
      );

      expect(tuck.evaluate(signals, isHolding: false).isValidHoldPosture, isTrue);
      expect(
        straightLeg.evaluate(signals, isHolding: false).isValidHoldPosture,
        isFalse,
      );
      expect(
        overhead.evaluate(signals, isHolding: false).isValidHoldPosture,
        isFalse,
      );
    });

    test('R34 exposes normalized shoulder and heel elevation measurements', () {
      const measurement = HollowHoldLimbElevationMeasurement();
      final values = measurement.measure(
        _hollowPose(),
        side: HoldSide.left,
      );

      expect(values.shoulderElevation, isNotNull);
      expect(values.heelElevation, isNotNull);
    });
  });
}

RangeRepRepSummary _summary({required double primaryRom}) {
  return RangeRepRepSummary(
    repIndex: 1,
    minAngle: 100,
    worstFormMetric: 0,
    descentDuration: const Duration(seconds: 1),
    ascentDuration: const Duration(seconds: 1),
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    startAngle: 160,
    primaryRom: primaryRom,
  );
}

Pose _plankPose({required double scale}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        -1 * scale,
        0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        0,
        1 * scale,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftAnkle: buildLandmark(
        PoseLandmarkType.leftAnkle,
        1 * scale,
        0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftElbow: buildLandmark(
        PoseLandmarkType.leftElbow,
        0,
        0,
        likelihood: 0.99,
      ),
    },
  );
}

Pose _bicepsPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        0,
        0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        1,
        3,
        likelihood: 0.99,
      ),
      PoseLandmarkType.rightShoulder: buildLandmark(
        PoseLandmarkType.rightShoulder,
        4,
        0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.rightHip: buildLandmark(
        PoseLandmarkType.rightHip,
        5,
        3,
        likelihood: 0.99,
      ),
    },
  );
}

Pose _hollowPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: buildLandmark(
        PoseLandmarkType.leftShoulder,
        0,
        0,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftHip: buildLandmark(
        PoseLandmarkType.leftHip,
        2,
        2,
        likelihood: 0.99,
      ),
      PoseLandmarkType.leftHeel: buildLandmark(
        PoseLandmarkType.leftHeel,
        5,
        1,
        likelihood: 0.99,
      ),
    },
  );
}
