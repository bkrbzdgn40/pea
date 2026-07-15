import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('PoseAngleLandmarks', () {
    test('range-rep signal definitions use the shared angle value type', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Squat',
        'primaryJoint': 'leftKnee',
        'joint1': 'leftHip',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 150.0,
        'thresholdPeak': 95.0,
        'rangeRepSignals': <String, dynamic>{
          'postureAngle': <String, dynamic>{
            'first': 'leftShoulder',
            'middle': 'leftHip',
            'last': 'leftKnee',
          },
          'depthMetric': <String, dynamic>{'source': 'primaryMetric'},
        },
      });

      final postureAngle = config.rangeRepSignals
          ?.definitionFor(RangeRepSignal.postureAngle)
          ?.angle;

      expect(postureAngle, isA<PoseAngleLandmarks>());
      expect(postureAngle?.first, PoseLandmarkType.leftShoulder);
      expect(postureAngle?.middle, PoseLandmarkType.leftHip);
      expect(postureAngle?.last, PoseLandmarkType.leftKnee);
    });

    test('hold signal definitions use the shared angle value type', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Plank',
        'primaryJoint': 'leftHip',
        'joint1': 'leftShoulder',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 168.0,
        'thresholdPeak': 0.0,
        'holdSignals': <String, dynamic>{
          'referenceSide': 'left',
          'alignment': <String, dynamic>{
            'first': 'leftShoulder',
            'middle': 'leftHip',
            'last': 'leftAnkle',
          },
        },
      });

      final alignment = config.holdSignals?.definitionFor(HoldSignal.alignment);

      expect(alignment, isA<PoseAngleLandmarks>());
      expect(alignment?.first, PoseLandmarkType.leftShoulder);
      expect(alignment?.middle, PoseLandmarkType.leftHip);
      expect(alignment?.last, PoseLandmarkType.leftAnkle);
      expect(config.holdSignals?.referenceSide, HoldSide.left);
    });

    test('rejects duplicate landmarks in shared range-rep angle triples', () {
      expect(
        () => ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Squat',
          'primaryJoint': 'leftKnee',
          'joint1': 'leftHip',
          'joint2': 'leftAnkle',
          'thresholdNeutral': 160.0,
          'thresholdActive': 150.0,
          'thresholdPeak': 95.0,
          'rangeRepSignals': <String, dynamic>{
            'postureAngle': <String, dynamic>{
              'first': 'leftShoulder',
              'middle': 'leftHip',
              'last': 'leftHip',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.rangeRepSignals.postureAngle'),
          ),
        ),
      );
    });

    test('rejects extra keys in shared hold angle triples', () {
      expect(
        () => ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Plank',
          'primaryJoint': 'leftHip',
          'joint1': 'leftShoulder',
          'joint2': 'leftAnkle',
          'thresholdNeutral': 160.0,
          'thresholdActive': 168.0,
          'thresholdPeak': 0.0,
          'holdSignals': <String, dynamic>{
            'referenceSide': 'left',
            'support': <String, dynamic>{
              'first': 'leftShoulder',
              'middle': 'leftElbow',
              'last': 'leftWrist',
              'source': 'primaryMetric',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.holdSignals.support'),
          ),
        ),
      );
    });
  });
}
