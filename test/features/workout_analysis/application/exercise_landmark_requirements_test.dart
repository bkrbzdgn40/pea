import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const requirements = ExerciseLandmarkRequirements();

  group('ExerciseLandmarkRequirements range-rep pose acceptance', () {
    test('squat keeps its pose-acceptance landmark set unchanged', () {
      final config = loadExerciseConfig('assets/config/exercises/squat.json');
      final supportedAnalysis = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
        side: RangeRepSide.left,
      );
      final poseAcceptance = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
        side: RangeRepSide.left,
      );

      expect(
        poseAcceptance.requiredLandmarks,
        equals(supportedAnalysis.requiredLandmarks),
      );
      expect(
        poseAcceptance.requiredAngleTriplets.map(_tripletKey).toList(),
        equals(
          supportedAnalysis.requiredAngleTriplets.map(_tripletKey).toList(),
        ),
      );
    });

    test('push-up keeps its pose-acceptance landmark set unchanged', () {
      final config = loadExerciseConfig('assets/config/exercises/push_up.json');
      final supportedAnalysis = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
        side: RangeRepSide.left,
      );
      final poseAcceptance = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
        rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
        side: RangeRepSide.left,
      );

      expect(
        poseAcceptance.requiredLandmarks,
        equals(supportedAnalysis.requiredLandmarks),
      );
      expect(
        poseAcceptance.requiredAngleTriplets.map(_tripletKey).toList(),
        equals(
          supportedAnalysis.requiredAngleTriplets.map(_tripletKey).toList(),
        ),
      );
    });

    test(
      'sit-up pose acceptance only requires the primary shoulder-hip-knee geometry',
      () {
        final requirementSet = requirements.resolve(
          config: loadExerciseConfig('assets/config/exercises/sit_up.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
          rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
          side: RangeRepSide.left,
        );

        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
        });
        expect(requirementSet.requiredAngleTriplets.map(_tripletKey), <String>[
          'leftShoulder->leftHip->leftKnee',
        ]);
      },
    );

    test(
      'sit-up analysis-supported signals still include the advisory ankle geometry',
      () {
        final requirementSet = requirements.resolve(
          config: loadExerciseConfig('assets/config/exercises/sit_up.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
          side: RangeRepSide.left,
        );

        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        });
        expect(
          requirementSet.requiredAngleTriplets.map(_tripletKey),
          containsAll(<String>[
            'leftShoulder->leftHip->leftKnee',
            'leftHip->leftKnee->leftAnkle',
          ]),
        );
      },
    );

    test(
      'sit-up pose acceptance mirrors the primary geometry to the right side',
      () {
        final requirementSet = requirements.resolve(
          config: loadExerciseConfig('assets/config/exercises/sit_up.json'),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
          rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
          side: RangeRepSide.right,
        );

        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.rightKnee,
        });
        expect(requirementSet.requiredAngleTriplets.map(_tripletKey), <String>[
          'rightShoulder->rightHip->rightKnee',
        ]);
      },
    );
  });

  group('ExerciseLandmarkRequirements hold resolution', () {
    test('hold resolves the exact required landmark set', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      });
    });

    test('hold resolves the exact angle triplets', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        requirementSet.requiredAngleTriplets.map(_tripletKey),
        unorderedEquals(<String>{
          'leftShoulder->leftHip->leftAnkle',
          'leftShoulder->leftElbow->leftWrist',
          'leftHip->leftKnee->leftAnkle',
        }),
      );
    });

    test('hold requirement resolution follows contract.requiredSignals', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContract(
          family: HoldAnalysisFamily.plank,
          requiredSignals: const <HoldSignal>{
            HoldSignal.alignment,
            HoldSignal.support,
          },
        ),
        holdSide: HoldSide.left,
      );

      expect(
        requirementSet.requiredAngleTriplets.map(_tripletKey),
        unorderedEquals(<String>{
          'leftShoulder->leftHip->leftAnkle',
          'leftShoulder->leftElbow->leftWrist',
        }),
      );
      expect(
        requirementSet.requiredLandmarks.contains(PoseLandmarkType.leftKnee),
        isFalse,
      );
    });

    test('hold resolves the exact required segments', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        requirementSet.requiredSegments.map(_segmentKey),
        unorderedEquals(<String>{
          'leftShoulder->leftHip',
          'leftHip->leftAnkle',
          'leftShoulder->leftElbow',
          'leftElbow->leftWrist',
          'leftHip->leftKnee',
          'leftKnee->leftAnkle',
        }),
      );
    });

    test('hold resolves the mirrored right-side landmark set', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.right,
      );

      expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      });
      expect(
        requirementSet.requiredAngleTriplets.map(_tripletKey),
        unorderedEquals(<String>{
          'rightShoulder->rightHip->rightAnkle',
          'rightShoulder->rightElbow->rightWrist',
          'rightHip->rightKnee->rightAnkle',
        }),
      );
    });

    test(
      'hold requirements follow configured signal geometry instead of hardcoded plank triplets',
      () {
        final requirementSet = requirements.resolve(
          config: _alternateHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
          holdSide: HoldSide.left,
        );

        expect(
          requirementSet.requiredAngleTriplets.map(_tripletKey),
          unorderedEquals(<String>{
            'leftShoulder->leftHip->rightHip',
            'leftHip->leftElbow->leftWrist',
            'leftShoulder->leftKnee->leftAnkle',
          }),
        );
        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        });
      },
    );

    test(
      'hold requirements mirror mixed-side configured geometry for the opposite target side',
      () {
        final requirementSet = requirements.resolve(
          config: _alternateHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
          holdSide: HoldSide.right,
        );

        expect(
          requirementSet.requiredAngleTriplets.map(_tripletKey),
          unorderedEquals(<String>{
            'rightShoulder->rightHip->leftHip',
            'rightHip->rightElbow->rightWrist',
            'rightShoulder->rightKnee->rightAnkle',
          }),
        );
      },
    );
  });
}

ExerciseConfig _holdConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
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
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
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

String _tripletKey(PoseAngleTriplet triplet) {
  return '${triplet.first.name}->${triplet.middle.name}->${triplet.last.name}';
}

String _segmentKey(PoseLandmarkSegment segment) {
  return '${segment.first.name}->${segment.second.name}';
}
