import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';

void main() {
  group('ExerciseConfig.fromMap', () {
    test('parses a squat-style range-rep config', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Squat',
        'primaryJoint': 'leftKnee',
        'joint1': 'leftHip',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 150.0,
        'thresholdPeak': 95.0,
        'idealDescentSeconds': 1.5,
        'idealAscentSeconds': 1.0,
        'formThreshold': 45.0,
        'targetMinAngle': 70.0,
        'tempoPenaltyPerSecond': 20.0,
        'rangeRepScoreWeights': <String, dynamic>{
          'descentControlWeight': 1.0,
          'ascentControlWeight': 1.0,
        },
        'rangeRepPhaseQuality': <String, dynamic>{
          'minDescendingMillis': 300,
          'minAscendingMillis': 250,
        },
      });

      expect(config.name, 'Squat');
      expect(config.primaryJoint, PoseLandmarkType.leftKnee);
      expect(config.thresholdPeak, 95.0);
      expect(config.holdPosture, isNull);
      expect(config.rangeRepScoreWeights?.descentControlWeight, 1.0);
      expect(config.rangeRepScoreWeights?.ascentControlWeight, 1.0);
      expect(config.rangeRepPhaseQuality?.minDescendingMillis, 300);
      expect(config.rangeRepPhaseQuality?.minAscendingMillis, 250);
    });

    test('parses a hold posture config and applies fallback thresholds', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Plank',
        'primaryJoint': 'leftHip',
        'joint1': 'leftShoulder',
        'joint2': 'leftAnkle',
        'holdPosture': <String, dynamic>{
          'activePostureAngle': 160.0,
          'bodyLineEntryAngle': 168.0,
          'bodyLineSustainAngle': 166.0,
          'armSupportMinAngle': 60.0,
          'armSupportMaxAngle': 120.0,
          'legExtensionMinAngle': 165.0,
          'breakGraceMillis': 300,
        },
      });

      expect(config.name, 'Plank');
      expect(config.thresholdNeutral, 160.0);
      expect(config.thresholdActive, 168.0);
      expect(config.thresholdPeak, 0.0);
      expect(
        config.resolvedHoldPosture.breakGraceDuration,
        const Duration(milliseconds: 300),
      );
    });

    test('throws a useful FormatException for an invalid landmark', () {
      expect(
        () => ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Squat',
          'primaryJoint': 'leftWing',
          'joint1': 'leftHip',
          'joint2': 'leftAnkle',
          'thresholdNeutral': 160.0,
          'thresholdActive': 150.0,
          'thresholdPeak': 95.0,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported PoseLandmarkType for primaryJoint'),
          ),
        ),
      );
    });

    test('throws a useful FormatException for an invalid numeric field', () {
      expect(
        () => ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Squat',
          'primaryJoint': 'leftKnee',
          'joint1': 'leftHip',
          'joint2': 'leftAnkle',
          'thresholdNeutral': true,
          'thresholdActive': 150.0,
          'thresholdPeak': 95.0,
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.thresholdNeutral must be a number.'),
          ),
        ),
      );
    });
  });
}
