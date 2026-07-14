import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('ExerciseConfig.fromMap', () {
    test('parses explicit range-rep signals from squat asset config', () {
      final rawJson = File(
        'assets/config/exercises/squat.json',
      ).readAsStringSync();
      final config = ExerciseConfig.fromMap(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(config.name, 'Squat');
      expect(config.primaryJoint, PoseLandmarkType.leftKnee);
      expect(config.rangeRepSignals, isNotNull);
      expect(config.usesLegacyRangeRepSignalFallback, isFalse);
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.first,
        PoseLandmarkType.leftShoulder,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.endRangeMetric)
            ?.angle
            ?.last,
        PoseLandmarkType.leftAnkle,
      );
    });

    test('parses explicit range-rep signals from push-up asset config', () {
      final rawJson = File(
        'assets/config/exercises/push_up.json',
      ).readAsStringSync();
      final config = ExerciseConfig.fromMap(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(config.name, 'Push-Up');
      expect(config.primaryJoint, PoseLandmarkType.leftElbow);
      expect(config.rangeRepSignals, isNotNull);
      expect(config.usesLegacyRangeRepSignalFallback, isFalse);
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.middle,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.alignmentMetric)
            ?.angle
            ?.last,
        PoseLandmarkType.leftAnkle,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.endRangeMetric)
            ?.angle
            ?.middle,
        PoseLandmarkType.leftElbow,
      );
    });

    test('parses rangeRepSignals angle triples and source aliases', () {
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
          'alignmentMetric': <String, dynamic>{
            'first': 'leftShoulder',
            'middle': 'leftHip',
            'last': 'leftAnkle',
          },
        },
      });

      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.middle,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.alignmentMetric)
            ?.angle
            ?.last,
        PoseLandmarkType.leftAnkle,
      );
    });

    test('keeps old range-rep config without rangeRepSignals valid', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Legacy Squat',
        'primaryJoint': 'leftKnee',
        'joint1': 'leftHip',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 150.0,
        'thresholdPeak': 95.0,
      });

      expect(config.rangeRepSignals, isNull);
      expect(config.usesLegacyRangeRepSignalFallback, isTrue);
      expect(
        config.resolvedRangeRepSignals?.definitionFor(
          RangeRepSignal.postureAngle,
        ),
        isNotNull,
      );
    });

    test('keeps hold/plank config valid', () {
      final rawJson = File(
        'assets/config/exercises/plank.json',
      ).readAsStringSync();
      final config = ExerciseConfig.fromMap(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );

      expect(config.name, 'Plank');
      expect(config.holdSignals, isNotNull);
      expect(
        config.holdSignals?.definitionFor(HoldSignal.alignment)?.middle,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.support)?.middle,
        PoseLandmarkType.leftElbow,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.extension)?.last,
        PoseLandmarkType.leftAnkle,
      );
      expect(config.rangeRepSignals, isNull);
      expect(config.resolvedRangeRepSignals, isNull);
      expect(config.thresholdNeutral, 160.0);
      expect(config.thresholdActive, 168.0);
    });

    test('parses explicit hold signals from inline plank config', () {
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
        'holdSignals': <String, dynamic>{
          'alignment': <String, dynamic>{
            'first': 'leftShoulder',
            'middle': 'leftHip',
            'last': 'leftAnkle',
          },
          'support': <String, dynamic>{
            'first': 'leftShoulder',
            'middle': 'leftElbow',
            'last': 'leftWrist',
          },
          'extension': <String, dynamic>{
            'first': 'leftHip',
            'middle': 'leftKnee',
            'last': 'leftAnkle',
          },
        },
      });

      expect(
        config.holdSignals?.definitionFor(HoldSignal.alignment)?.first,
        PoseLandmarkType.leftShoulder,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.support)?.last,
        PoseLandmarkType.leftWrist,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.extension)?.middle,
        PoseLandmarkType.leftKnee,
      );
    });

    test('rejects invalid landmark names inside rangeRepSignals', () {
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
              'first': 'leftWing',
              'middle': 'leftHip',
              'last': 'leftKnee',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.rangeRepSignals.postureAngle.first'),
          ),
        ),
      );
    });

    test('rejects invalid source names inside rangeRepSignals', () {
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
            'depthMetric': <String, dynamic>{'source': 'secondaryMetric'},
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported RangeRepSignalSource'),
          ),
        ),
      );
    });

    test('rejects unknown keys inside rangeRepSignals', () {
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
            'mysterySignal': <String, dynamic>{'source': 'primaryMetric'},
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported ExerciseConfig.rangeRepSignals key'),
          ),
        ),
      );
    });

    test('rejects invalid landmark names inside holdSignals', () {
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
            'alignment': <String, dynamic>{
              'first': 'leftWing',
              'middle': 'leftHip',
              'last': 'leftAnkle',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.holdSignals.alignment.first'),
          ),
        ),
      );
    });

    test('rejects unknown keys inside holdSignals', () {
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
            'brace': <String, dynamic>{
              'first': 'leftShoulder',
              'middle': 'leftHip',
              'last': 'leftAnkle',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('Unsupported ExerciseConfig.holdSignals key'),
          ),
        ),
      );
    });

    test('rejects hold signal definitions with extra keys', () {
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

    test('rejects duplicate landmarks inside a hold signal definition', () {
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
            'extension': <String, dynamic>{
              'first': 'leftHip',
              'middle': 'leftKnee',
              'last': 'leftKnee',
            },
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            contains('ExerciseConfig.holdSignals.extension'),
          ),
        ),
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
