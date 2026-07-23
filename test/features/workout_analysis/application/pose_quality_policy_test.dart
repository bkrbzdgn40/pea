import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const policy = PoseQualityPolicy();

  group('PoseQualityPolicy', () {
    test('all required squat landmarks with high likelihood are accepted', () {
      final assessment = policy.assess(
        pose: _squatPose(),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide, isNotNull);
      expect(
        assessment.acceptedRangeRepSides,
        containsAll(<RangeRepSide>[RangeRepSide.left, RangeRepSide.right]),
      );
    });

    test('quality statistics preserve likelihood aggregation semantics', () {
      const requirementSet = ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[],
        requiredSegments: <PoseLandmarkSegment>[],
      );
      final assessment = policy.assessRequirementSet(
        pose: Pose(
          landmarks: <PoseLandmarkType, PoseLandmark>{
            PoseLandmarkType.leftShoulder: _landmark(
              PoseLandmarkType.leftShoulder,
              0,
              0,
              likelihood: 0.90,
            ),
            PoseLandmarkType.leftHip: _landmark(
              PoseLandmarkType.leftHip,
              0,
              1,
              likelihood: 0.49,
            ),
            PoseLandmarkType.leftKnee: _landmark(
              PoseLandmarkType.leftKnee,
              0,
              2,
              likelihood: 0.70,
            ),
          },
        ),
        requirementSet: requirementSet,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.lowLandmarkLikelihood,
      );
      expect(assessment.minimumRequiredLikelihood, closeTo(0.49, 1e-12));
      expect(
        assessment.meanRequiredLikelihood,
        closeTo((0.90 + 0.49 + 0.70) / 3, 1e-12),
      );
      expect(assessment.requiredLandmarkCount, 3);
      expect(assessment.acceptedLandmarkCount, 2);
    });

    test('non-finite rejection preserves first failing landmark telemetry', () {
      const requirementSet = ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[],
        requiredSegments: <PoseLandmarkSegment>[],
      );
      final assessment = policy.assessRequirementSet(
        pose: Pose(
          landmarks: <PoseLandmarkType, PoseLandmark>{
            PoseLandmarkType.leftShoulder: _landmark(
              PoseLandmarkType.leftShoulder,
              0,
              0,
              likelihood: 0.60,
            ),
            PoseLandmarkType.leftHip: _landmark(
              PoseLandmarkType.leftHip,
              double.nan,
              1,
              likelihood: 0.80,
            ),
            PoseLandmarkType.leftKnee: _landmark(
              PoseLandmarkType.leftKnee,
              0,
              2,
              likelihood: 0.90,
            ),
          },
        ),
        requirementSet: requirementSet,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.nonFiniteCoordinate,
      );
      expect(assessment.minimumRequiredLikelihood, closeTo(0.80, 1e-12));
      expect(
        assessment.meanRequiredLikelihood,
        closeTo((0.60 + 0.80 + 0.90) / 3, 1e-12),
      );
      expect(assessment.acceptedLandmarkCount, 0);
    });

    test('degenerate geometry still takes precedence over low confidence', () {
      const requirementSet = ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[
          PoseAngleTriplet(
            first: PoseLandmarkType.leftShoulder,
            middle: PoseLandmarkType.leftHip,
            last: PoseLandmarkType.leftKnee,
          ),
        ],
        requiredSegments: <PoseLandmarkSegment>[],
      );
      final assessment = policy.assessRequirementSet(
        pose: Pose(
          landmarks: <PoseLandmarkType, PoseLandmark>{
            PoseLandmarkType.leftShoulder: _landmark(
              PoseLandmarkType.leftShoulder,
              0,
              0,
              likelihood: 0.40,
            ),
            PoseLandmarkType.leftHip: _landmark(
              PoseLandmarkType.leftHip,
              0,
              0,
              likelihood: 0.80,
            ),
            PoseLandmarkType.leftKnee: _landmark(
              PoseLandmarkType.leftKnee,
              0,
              2,
              likelihood: 0.90,
            ),
          },
        ),
        requirementSet: requirementSet,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.degenerateGeometry,
      );
      expect(assessment.minimumRequiredLikelihood, closeTo(0.40, 1e-12));
      expect(
        assessment.meanRequiredLikelihood,
        closeTo((0.40 + 0.80 + 0.90) / 3, 1e-12),
      );
      expect(assessment.acceptedLandmarkCount, 3);
    });

    test('one required landmark below 0.50 is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipLikelihood: 0.49, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.lowLandmarkLikelihood,
      );
    });

    test('mean below 0.65 is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(
          defaultLikelihood: 0.60,
          leftHipLikelihood: 0.60,
          includeRightSide: false,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(assessment.rejectionReason, PoseRejectionReason.lowMeanLikelihood);
    });

    test('missing required landmark is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(includeLeftKnee: false, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.missingRequiredLandmark,
      );
    });

    test('NaN coordinate is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipX: double.nan, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.nonFiniteCoordinate,
      );
    });

    test('infinite coordinate is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipX: double.infinity, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.nonFiniteCoordinate,
      );
    });

    test('degenerate angle triplet is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(
          leftHipX: 0,
          leftHipY: 1,
          leftKneeX: 0,
          leftKneeY: 1,
          includeRightSide: false,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.degenerateGeometry,
      );
    });

    test('squat valid left and unavailable right accepts left side', () {
      final assessment = policy.assess(
        pose: _squatPose(includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide?.name, 'left');
      expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
        RangeRepSide.left,
      });
      expect(assessment.preferredRangeRepSide, RangeRepSide.left);
    });

    test('range-rep quality keeps both accepted sides and prefers the stronger '
        'one', () {
      final assessment = policy.assess(
        pose: _squatPose(
          defaultLikelihood: 0.80,
          leftHipLikelihood: 0.70,
          includeRightSide: true,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
        RangeRepSide.left,
        RangeRepSide.right,
      });
      expect(assessment.preferredRangeRepSide, RangeRepSide.right);
    });

    test('push-up required landmark set is accepted', () {
      final assessment = policy.assess(
        pose: _pushUpPose(),
        config: _loadConfig('assets/config/exercises/push_up.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(assessment.isAccepted, isTrue);
    });

    test('sit-up complete left-side geometry is accepted', () {
      final assessment = policy.assess(
        pose: buildSitUpPose(
          primaryAngle: 90,
          formAngle: 120,
          includeRightSide: false,
        ),
        config: _loadConfig('assets/config/exercises/sit_up.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
        RangeRepSide.left,
      });
      expect(assessment.preferredRangeRepSide, RangeRepSide.left);
    });

    test('sit-up rejects the side when a primary landmark is missing', () {
      final assessment = policy.assess(
        pose: buildSitUpPose(
          primaryAngle: 90,
          formAngle: 120,
          includeRightSide: false,
          missingLandmarks: const <PoseLandmarkType>{
            PoseLandmarkType.leftShoulder,
          },
        ),
        config: _loadConfig('assets/config/exercises/sit_up.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.missingRequiredLandmark,
      );
    });

    test(
      'sit-up keeps pose acceptance when only the advisory ankle likelihood dips',
      () {
        final assessment = policy.assess(
          pose: buildSitUpPose(
            primaryAngle: 90,
            formAngle: 120,
            includeRightSide: false,
            likelihoodOverrides: const <PoseLandmarkType, double>{
              PoseLandmarkType.leftAnkle: 0.10,
            },
          ),
          config: _loadConfig('assets/config/exercises/sit_up.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
          RangeRepSide.left,
        });
        expect(assessment.preferredRangeRepSide, RangeRepSide.left);
      },
    );

    test('sit-up valid bilateral landmarks accept both sides', () {
      final assessment = policy.assess(
        pose: buildSitUpPose(primaryAngle: 85, formAngle: 125),
        config: _loadConfig('assets/config/exercises/sit_up.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(assessment.isAccepted, isTrue);
      expect(
        assessment.acceptedRangeRepSides,
        containsAll(<RangeRepSide>[RangeRepSide.left, RangeRepSide.right]),
      );
    });

    test(
      'biceps curl bilateral pose requires both visible arms and both hips',
      () {
        final assessment = policy.assess(
          pose: buildBicepsCurlPose(
            leftPrimaryAngle: 90,
            rightPrimaryAngle: 92,
            leftUpperArmDriftAngle: 20,
            rightUpperArmDriftAngle: 20,
          ),
          config: _loadConfig('assets/config/exercises/biceps_curl.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.bicepsCurl,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
          RangeRepSide.left,
          RangeRepSide.right,
        });
        expect(assessment.preferredRangeRepSide, isNull);
      },
    );

    test('biceps curl rejects a single visible arm in bilateral mode', () {
      final assessment = policy.assess(
        pose: buildBicepsCurlPose(
          leftPrimaryAngle: 90,
          includeRightSide: false,
        ),
        config: _loadConfig('assets/config/exercises/biceps_curl.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.bicepsCurl,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.missingRequiredLandmark,
      );
    });

    test(
      'biceps curl rejects when a required hip for upper-arm form is missing',
      () {
        final assessment = policy.assess(
          pose: buildBicepsCurlPose(
            leftPrimaryAngle: 90,
            rightPrimaryAngle: 92,
            missingLandmarks: const <PoseLandmarkType>{
              PoseLandmarkType.rightHip,
            },
          ),
          config: _loadConfig('assets/config/exercises/biceps_curl.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.bicepsCurl,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.missingRequiredLandmark,
        );
      },
    );

    test('plank valid required landmarks are accepted', () {
      final assessment = policy.assess(
        pose: _plankPose(),
        config: _plankConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide, isNull);
      expect(assessment.acceptedHoldSides, <HoldSide>{HoldSide.left});
      expect(assessment.preferredHoldSide, HoldSide.left);
    });

    group('hold quality', () {
      test('hollow hold valid left-side required landmarks are accepted', () {
        final assessment = policy.assess(
          pose: buildHollowHoldPose(includeRightSide: false),
          config: buildHollowHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.hollowHold,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedHoldSides, <HoldSide>{HoldSide.left});
        expect(assessment.preferredHoldSide, HoldSide.left);
      });

      test('hollow hold valid right-side required landmarks are accepted', () {
        final assessment = policy.assess(
          pose: buildHollowHoldPose(includeLeftSide: false),
          config: buildHollowHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.hollowHold,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedHoldSides, <HoldSide>{HoldSide.right});
        expect(assessment.preferredHoldSide, HoldSide.right);
      });

      test('hollow hold rejects the side when a required wrist is missing', () {
        final assessment = policy.assess(
          pose: buildHollowHoldPose(
            includeRightSide: false,
            missingLandmarks: const <PoseLandmarkType>{
              PoseLandmarkType.leftWrist,
            },
          ),
          config: buildHollowHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.hollowHold,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.missingRequiredLandmark,
        );
      });

      for (final scenario in <({PoseLandmarkType landmark, String name})>[
        (landmark: PoseLandmarkType.leftShoulder, name: 'left shoulder'),
        (landmark: PoseLandmarkType.leftElbow, name: 'left elbow'),
        (landmark: PoseLandmarkType.leftWrist, name: 'left wrist'),
        (landmark: PoseLandmarkType.leftHip, name: 'left hip'),
        (landmark: PoseLandmarkType.leftKnee, name: 'left knee'),
        (landmark: PoseLandmarkType.leftAnkle, name: 'left ankle'),
      ]) {
        test('missing required hold landmark ${scenario.name} is rejected', () {
          final assessment = policy.assess(
            pose: _plankPose(
              missingLandmarks: <PoseLandmarkType>{scenario.landmark},
            ),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isFalse);
          expect(
            assessment.rejectionReason,
            PoseRejectionReason.missingRequiredLandmark,
          );
        });
      }

      test('required hold landmark below 0.50 likelihood is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(
            likelihoodOverrides: const <PoseLandmarkType, double>{
              PoseLandmarkType.leftHip: 0.49,
            },
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.lowLandmarkLikelihood,
        );
      });

      test('mean required hold likelihood below 0.65 is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(defaultLikelihood: 0.60),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.lowMeanLikelihood,
        );
      });

      test('non-finite required hold coordinate is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(
            coordinateOverrides: <PoseLandmarkType, _CoordinateOverride>{
              PoseLandmarkType.leftHip: const _CoordinateOverride(
                double.nan,
                0,
              ),
            },
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.nonFiniteCoordinate,
        );
      });

      for (final scenario
          in <
            ({
              String name,
              Map<PoseLandmarkType, _CoordinateOverride> overrides,
            })
          >[
            (
              name: 'degenerate body-line triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftHip: const _CoordinateOverride(-1, 0),
              },
            ),
            (
              name: 'degenerate arm-support triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftElbow: const _CoordinateOverride(-1, 0),
              },
            ),
            (
              name: 'degenerate leg-extension triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftKnee: const _CoordinateOverride(0, 0),
              },
            ),
          ]) {
        test(scenario.name, () {
          final assessment = policy.assess(
            pose: _plankPose(coordinateOverrides: scenario.overrides),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isFalse);
          expect(
            assessment.rejectionReason,
            PoseRejectionReason.degenerateGeometry,
          );
        });
      }

      test('right-only hold quality is accepted on the right side', () {
        final assessment = policy.assess(
          pose: _plankPose(rightOnly: true),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedHoldSides, <HoldSide>{HoldSide.right});
        expect(assessment.preferredHoldSide, HoldSide.right);
      });

      test(
        'hold quality uses config-driven requirements for test-only signal geometry',
        () {
          final assessment = policy.assess(
            pose: _alternateHoldPose(),
            config: _alternateHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isTrue);
          expect(assessment.acceptedSide, isNull);
          expect(assessment.acceptedHoldSides, <HoldSide>{HoldSide.left});
          expect(assessment.preferredHoldSide, HoldSide.left);
          expect(assessment.requiredLandmarkCount, 7);
        },
      );

      test(
        'hold quality accepts both sides and prefers the higher-quality side',
        () {
          final assessment = policy.assess(
            pose: _bilateralPlankPose(
              leftLikelihood: 0.70,
              rightLikelihood: 0.95,
            ),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isTrue);
          expect(assessment.acceptedHoldSides, <HoldSide>{
            HoldSide.left,
            HoldSide.right,
          });
          expect(assessment.preferredHoldSide, HoldSide.right);
        },
      );

      test(
        'side plank prefers the side whose elbow is physically below the shoulder',
        () {
          final assessment = policy.assess(
            pose: _bilateralSidePlankPose(
              supportSideLikelihood: 0.80,
              nonSupportSideLikelihood: 0.99,
            ),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.sidePlank,
          );

          expect(assessment.isAccepted, isTrue);
          expect(assessment.acceptedHoldSides, <HoldSide>{
            HoldSide.left,
            HoldSide.right,
          });
          expect(assessment.preferredHoldSide, HoldSide.left);
        },
      );

      test('hold quality uses left tie-break when both sides are equal', () {
        final assessment = policy.assess(
          pose: _bilateralPlankPose(
            leftLikelihood: 0.95,
            rightLikelihood: 0.95,
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isTrue);
        expect(assessment.acceptedHoldSides, <HoldSide>{
          HoldSide.left,
          HoldSide.right,
        });
        expect(assessment.preferredHoldSide, HoldSide.left);
      });

      test('required hold side only accepts the locked side', () {
        final assessment = policy.assess(
          pose: _bilateralPlankPose(
            leftLikelihood: 0.40,
            rightLikelihood: 0.95,
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
          requiredHoldSide: HoldSide.left,
        );

        expect(assessment.isAccepted, isFalse);
        expect(assessment.preferredHoldSide, HoldSide.left);
        expect(assessment.acceptedHoldSides, isEmpty);
      });
    });
  });
}

ExerciseConfig _loadConfig(String path) {
  final rawJson = File(path).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
}

ExerciseConfig _legacySquatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 150,
    thresholdPeak: 95,
    formThreshold: 45,
    targetMinAngle: 70,
  );
}

ExerciseConfig _plankConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: PoseAngleLandmarks(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

ExerciseConfig _alternateHoldConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.rightHip,
      ),
      support: PoseAngleLandmarks(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

Pose _squatPose({
  bool includeLeftKnee = true,
  bool includeRightSide = true,
  double defaultLikelihood = 0.95,
  double leftHipLikelihood = 0.95,
  double leftHipX = 0,
  double leftHipY = 1,
  double leftKneeX = 1,
  double leftKneeY = 1,
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        leftHipX,
        leftHipY,
        likelihood: leftHipLikelihood,
      ),
      if (includeLeftKnee)
        PoseLandmarkType.leftKnee: _landmark(
          PoseLandmarkType.leftKnee,
          leftKneeX,
          leftKneeY,
          likelihood: defaultLikelihood,
        ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      if (includeRightSide) ...<PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.rightShoulder: _landmark(
          PoseLandmarkType.rightShoulder,
          4,
          2,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightHip: _landmark(
          PoseLandmarkType.rightHip,
          4,
          1,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightKnee: _landmark(
          PoseLandmarkType.rightKnee,
          3,
          1,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightAnkle: _landmark(
          PoseLandmarkType.rightAnkle,
          3,
          0,
          likelihood: defaultLikelihood,
        ),
      },
    },
  );
}

Pose _pushUpPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
      ),
      PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 1, 2),
      PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 1, 1),
      PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 2, 2),
      PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 4, 2),
    },
  );
}

Pose _plankPose({
  double defaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Map<PoseLandmarkType, _CoordinateOverride> coordinateOverrides =
      const <PoseLandmarkType, _CoordinateOverride>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }
    final override = coordinateOverrides[type];
    landmarks[type] = _landmark(
      type,
      override?.x ?? x,
      override?.y ?? y,
      likelihood: likelihoodOverrides[type] ?? defaultLikelihood,
    );
  }

  if (rightOnly) {
    addLandmark(PoseLandmarkType.rightShoulder, 1, 0);
    addLandmark(PoseLandmarkType.rightElbow, 0.5, 0);
    addLandmark(PoseLandmarkType.rightWrist, 0.5, -1);
    addLandmark(PoseLandmarkType.rightHip, 0, 0);
    addLandmark(PoseLandmarkType.rightKnee, -0.5, 0);
    addLandmark(PoseLandmarkType.rightAnkle, -1, 0);
  } else {
    addLandmark(PoseLandmarkType.leftShoulder, -1, 0);
    addLandmark(PoseLandmarkType.leftElbow, -0.5, 0);
    addLandmark(PoseLandmarkType.leftWrist, -0.5, -1);
    addLandmark(PoseLandmarkType.leftHip, 0, 0);
    addLandmark(PoseLandmarkType.leftKnee, 0.5, 0);
    addLandmark(PoseLandmarkType.leftAnkle, 1, 0);
  }

  return Pose(landmarks: landmarks);
}

Pose _bilateralSidePlankPose({
  required double supportSideLikelihood,
  required double nonSupportSideLikelihood,
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        -1,
        0,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        -1,
        1,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        0,
        1,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        0,
        0,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        0.5,
        0,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        1,
        0,
        likelihood: supportSideLikelihood,
      ),
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        -1,
        0,
        likelihood: nonSupportSideLikelihood,
      ),
      PoseLandmarkType.rightElbow: _landmark(
        PoseLandmarkType.rightElbow,
        -1,
        -1,
        likelihood: nonSupportSideLikelihood,
      ),
      PoseLandmarkType.rightWrist: _landmark(
        PoseLandmarkType.rightWrist,
        0,
        -1,
        likelihood: nonSupportSideLikelihood,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        0,
        0.2,
        likelihood: nonSupportSideLikelihood,
      ),
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        0.5,
        0.2,
        likelihood: nonSupportSideLikelihood,
      ),
      PoseLandmarkType.rightAnkle: _landmark(
        PoseLandmarkType.rightAnkle,
        1,
        0.2,
        likelihood: nonSupportSideLikelihood,
      ),
    },
  );
}

Pose _bilateralPlankPose({
  required double leftLikelihood,
  required double rightLikelihood,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(
    PoseLandmarkType type,
    double x,
    double y, {
    required double likelihood,
  }) {
    landmarks[type] = _landmark(type, x, y, likelihood: likelihood);
  }

  addLandmark(PoseLandmarkType.leftShoulder, -1, 0, likelihood: leftLikelihood);
  addLandmark(PoseLandmarkType.leftElbow, -0.5, 0, likelihood: leftLikelihood);
  addLandmark(PoseLandmarkType.leftWrist, -0.5, -1, likelihood: leftLikelihood);
  addLandmark(PoseLandmarkType.leftHip, 0, 0, likelihood: leftLikelihood);
  addLandmark(PoseLandmarkType.leftKnee, 0.5, 0, likelihood: leftLikelihood);
  addLandmark(PoseLandmarkType.leftAnkle, 1, 0, likelihood: leftLikelihood);

  addLandmark(
    PoseLandmarkType.rightShoulder,
    1,
    0,
    likelihood: rightLikelihood,
  );
  addLandmark(PoseLandmarkType.rightElbow, 0.5, 0, likelihood: rightLikelihood);
  addLandmark(
    PoseLandmarkType.rightWrist,
    0.5,
    -1,
    likelihood: rightLikelihood,
  );
  addLandmark(PoseLandmarkType.rightHip, 0, 0, likelihood: rightLikelihood);
  addLandmark(PoseLandmarkType.rightKnee, -0.5, 0, likelihood: rightLikelihood);
  addLandmark(PoseLandmarkType.rightAnkle, -1, 0, likelihood: rightLikelihood);

  return Pose(landmarks: landmarks);
}

Pose _alternateHoldPose({double defaultLikelihood = 0.95}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        0,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        1,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        2,
        -1,
        likelihood: defaultLikelihood,
      ),
    },
  );
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}

class _CoordinateOverride {
  const _CoordinateOverride(this.x, this.y);

  final double x;
  final double y;
}
