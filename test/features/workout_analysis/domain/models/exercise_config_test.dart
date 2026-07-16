import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('ExerciseConfig.fromMap', () {
    test(
      'parses the squat asset config without changing range-rep semantics',
      () {
        final config = _loadConfig('assets/config/exercises/squat.json');

        expect(config.name, 'Squat');
        expect(config.primaryJoint, PoseLandmarkType.leftKnee);
        expect(config.joint1, PoseLandmarkType.leftHip);
        expect(config.joint2, PoseLandmarkType.leftAnkle);
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
      },
    );

    test(
      'parses the push-up asset config without changing range-rep semantics',
      () {
        final config = _loadConfig('assets/config/exercises/push_up.json');

        expect(config.name, 'Push-Up');
        expect(config.primaryJoint, PoseLandmarkType.leftElbow);
        expect(config.joint1, PoseLandmarkType.leftShoulder);
        expect(config.joint2, PoseLandmarkType.leftWrist);
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
      },
    );

    test('parses the sit-up asset config as a strict range-rep definition', () {
      final config = _loadConfig('assets/config/exercises/sit_up.json');

      expect(config.name, 'Sit-up');
      expect(config.primaryJoint, PoseLandmarkType.leftHip);
      expect(config.joint1, PoseLandmarkType.leftShoulder);
      expect(config.joint2, PoseLandmarkType.leftKnee);
      expect(config.thresholdNeutral, 120.0);
      expect(config.thresholdActive, 113.0);
      expect(config.thresholdPeak, 73.0);
      expect(config.formThreshold, 70.0);
      expect(config.targetMinAngle, 70.0);
      expect(config.rangeRepSignals, isNotNull);
      expect(config.usesLegacyRangeRepSignalFallback, isFalse);
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.first,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.middle,
        PoseLandmarkType.leftKnee,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.last,
        PoseLandmarkType.leftAnkle,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
    });

    test('parses the plank asset config without changing hold semantics', () {
      final config = _loadConfig('assets/config/exercises/plank.json');

      expect(config.name, 'Plank');
      expect(config.holdSignals, isNotNull);
      expect(config.holdSignals?.referenceSide, HoldSide.left);
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
      expect(
        config.resolvedHoldPosture.breakGraceDuration,
        const Duration(milliseconds: 300),
      );
    });

    test('keeps legacy squat configs without rangeRepSignals valid', () {
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
      expect(
        config.resolvedRangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
    });

    test(
      'keeps hold threshold fallback behavior when thresholds are omitted',
      () {
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

        expect(config.thresholdNeutral, 160.0);
        expect(config.thresholdActive, 168.0);
        expect(config.thresholdPeak, 0.0);
      },
    );

    test(
      'keeps numeric string compatibility for root and nested numeric fields',
      () {
        final config = ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Plank',
          'primaryJoint': 'leftHip',
          'joint1': 'leftShoulder',
          'joint2': 'leftAnkle',
          'thresholdNeutral': '160.0',
          'thresholdActive': '168.0',
          'thresholdPeak': '0',
          'holdPosture': <String, dynamic>{
            'activePostureAngle': '160.0',
            'bodyLineEntryAngle': '168.0',
            'bodyLineSustainAngle': '166.0',
            'armSupportMinAngle': '60.0',
            'armSupportMaxAngle': '120.0',
            'legExtensionMinAngle': '165.0',
            'breakGraceMillis': '300',
          },
          'rangeRepScoreWeights': <String, dynamic>{'depthWeight': '0.25'},
        });

        expect(config.thresholdNeutral, 160.0);
        expect(
          config.holdPosture?.breakGraceDuration,
          const Duration(milliseconds: 300),
        );
        expect(config.rangeRepScoreWeights?.depthWeight, 0.25);
      },
    );

    test('keeps top-level unknown keys backward-compatible', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Squat',
        'primaryJoint': 'leftKnee',
        'joint1': 'leftHip',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 150.0,
        'thresholdPeak': 95.0,
        'futureTopLevelKey': 'still-accepted',
      });

      expect(config.name, 'Squat');
      expect(config.primaryJoint, PoseLandmarkType.leftKnee);
    });

    test('includes the exact root path for invalid root landmarks', () {
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
            contains('ExerciseConfig.primaryJoint'),
          ),
        ),
      );
    });

    test('includes the exact nested hold path for invalid landmarks', () {
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

    test('includes the exact nested range-rep path for invalid landmarks', () {
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

    test('includes the exact hold side path for invalid reference sides', () {
      expect(
        () => ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Plank',
          'primaryJoint': 'leftHip',
          'joint1': 'leftShoulder',
          'joint2': 'leftAnkle',
          'thresholdNeutral': 160.0,
          'thresholdActive': 168.0,
          'thresholdPeak': 0.0,
          'holdSignals': <String, dynamic>{'referenceSide': 'front'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message.toString(),
            'message',
            allOf(
              contains('HoldSide'),
              contains('ExerciseConfig.holdSignals.referenceSide'),
            ),
          ),
        ),
      );
    });

    test('includes the exact range-rep source path for invalid aliases', () {
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
            allOf(
              contains('RangeRepSignalSource'),
              contains('ExerciseConfig.rangeRepSignals.depthMetric.source'),
            ),
          ),
        ),
      );
    });

    test(
      'keeps numeric parse failures path-aware instead of leaking raw parse errors',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Plank',
            'primaryJoint': 'leftHip',
            'joint1': 'leftShoulder',
            'joint2': 'leftAnkle',
            'thresholdNeutral': 160.0,
            'thresholdActive': 168.0,
            'thresholdPeak': 0.0,
            'holdPosture': <String, dynamic>{
              'activePostureAngle': 160.0,
              'bodyLineEntryAngle': 168.0,
              'bodyLineSustainAngle': 166.0,
              'armSupportMinAngle': 60.0,
              'armSupportMaxAngle': 120.0,
              'legExtensionMinAngle': 165.0,
              'breakGraceMillis': 'oops',
            },
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              contains('ExerciseConfig.holdPosture.breakGraceMillis'),
            ),
          ),
        );
      },
    );

    test(
      'includes the exact nested numeric path for score weight failures',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Squat',
            'primaryJoint': 'leftKnee',
            'joint1': 'leftHip',
            'joint2': 'leftAnkle',
            'thresholdNeutral': 160.0,
            'thresholdActive': 150.0,
            'thresholdPeak': 95.0,
            'rangeRepScoreWeights': <String, dynamic>{'depthWeight': 'oops'},
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              contains('ExerciseConfig.rangeRepScoreWeights.depthWeight'),
            ),
          ),
        );
      },
    );

    test(
      'includes the exact object path when a nested object has the wrong type',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Plank',
            'primaryJoint': 'leftHip',
            'joint1': 'leftShoulder',
            'joint2': 'leftAnkle',
            'thresholdNeutral': 160.0,
            'thresholdActive': 168.0,
            'thresholdPeak': 0.0,
            'holdPosture': 'not-an-object',
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              contains('ExerciseConfig.holdPosture'),
            ),
          ),
        );
      },
    );

    test('rejects unknown nested hold signal keys with their parent path', () {
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
            contains('ExerciseConfig.holdSignals'),
          ),
        ),
      );
    });

    test(
      'rejects unknown nested range-rep signal keys with their parent path',
      () {
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
              contains('ExerciseConfig.rangeRepSignals'),
            ),
          ),
        );
      },
    );
  });
}

ExerciseConfig _loadConfig(String path) {
  final rawJson = File(path).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
}
