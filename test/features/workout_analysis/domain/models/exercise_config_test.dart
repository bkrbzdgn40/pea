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
      expect(config.thresholdPeak, 83.0);
      expect(config.formThreshold, 60.0);
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
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.transform,
        RangeRepSignalTransform.identity,
      );
    });

    test(
      'parses the biceps curl asset config with complement180 posture form',
      () {
        final config = _loadConfig('assets/config/exercises/biceps_curl.json');

        expect(config.name, 'Biceps Curl');
        expect(config.primaryJoint, PoseLandmarkType.leftElbow);
        expect(config.joint1, PoseLandmarkType.leftShoulder);
        expect(config.joint2, PoseLandmarkType.leftWrist);
        expect(config.thresholdNeutral, 155.0);
        expect(config.thresholdActive, 140.0);
        expect(config.thresholdPeak, 78.0);
        expect(config.formThreshold, 150.0);
        expect(config.targetMinAngle, 75.0);
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.postureAngle)
              ?.transform,
          RangeRepSignalTransform.complement180,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.transform,
          RangeRepSignalTransform.identity,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.source,
          RangeRepSignalSource.primaryMetric,
        );
      },
    );

    test('parses the bench-dip scoped triceps asset config', () {
      final config = _loadConfig('assets/config/exercises/triceps_dip.json');

      expect(config.name, 'Bench Dip');
      expect(config.primaryJoint, PoseLandmarkType.leftElbow);
      expect(config.joint1, PoseLandmarkType.leftShoulder);
      expect(config.joint2, PoseLandmarkType.leftWrist);
      expect(config.thresholdNeutral, 150.0);
      expect(config.thresholdActive, 130.0);
      expect(config.thresholdPeak, 100.0);
      expect(config.formThreshold, 100.0);
      expect(config.targetMinAngle, 90.0);
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.transform,
        RangeRepSignalTransform.complement180,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
    });

    test(
      'parses the lateral raise asset config with mild elbow-flexion tolerance',
      () {
        final config = _loadConfig(
          'assets/config/exercises/lateral_raise.json',
        );

        expect(config.name, 'Lateral Raise');
        expect(config.thresholdNeutral, 32.0);
        expect(config.thresholdActive, 35.0);
        expect(config.thresholdPeak, 80.0);
        expect(config.formThreshold, 145.0);
        expect(config.targetMaxAngle, 90.0);
      },
    );

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

    test(
      'parses the hollow hold asset config with typed Hollow posture semantics',
      () {
        final config = _loadConfig('assets/config/exercises/hollow_hold.json');

        expect(config.name, 'Hollow Hold');
        expect(config.holdSignals, isNotNull);
        expect(config.holdSignals?.referenceSide, HoldSide.left);
        expect(
          config.holdSignals?.definitionFor(HoldSignal.compression)?.middle,
          PoseLandmarkType.leftHip,
        );
        expect(
          config.holdSignals?.definitionFor(HoldSignal.armExtension)?.middle,
          PoseLandmarkType.leftShoulder,
        );
        expect(
          config.holdSignals?.definitionFor(HoldSignal.kneeExtension)?.middle,
          PoseLandmarkType.leftKnee,
        );
        expect(config.hollowHoldPosture, isNotNull);
        expect(config.hollowHoldPosture?.activePostureMaxAngle, 170.0);
        expect(config.hollowHoldPosture?.compressionEntryMaxAngle, 165.0);
        expect(config.hollowHoldPosture?.compressionSustainMaxAngle, 169.0);
        expect(config.hollowHoldPosture?.armExtensionMinAngle, 135.0);
        expect(config.hollowHoldPosture?.kneeExtensionMinAngle, 165.0);
        expect(
          config.hollowHoldPosture?.breakGraceDuration,
          const Duration(milliseconds: 300),
        );
        expect(config.thresholdNeutral, 170.0);
        expect(config.thresholdActive, 165.0);
        expect(config.rangeRepSignals, isNull);
      },
    );

    test('parses the Day 11 range-rep exercise configs', () {
      const expectations = <String, String>{
        'assets/config/exercises/calf_raise.json': 'Calf Raise',
        'assets/config/exercises/front_raise.json': 'Front Raise',
        'assets/config/exercises/glute_bridge.json': 'Glute Bridge',
        'assets/config/exercises/jumping_jack.json': 'Jumping Jack',
      };

      for (final entry in expectations.entries) {
        final config = _loadConfig(entry.key);
        expect(config.name, entry.value);
        expect(config.rangeRepSignals, isNotNull);
        expect(config.targetMaxAngle, isNotNull);
      }

      final frontRaise = _loadConfig(
        'assets/config/exercises/front_raise.json',
      );
      expect(frontRaise.thresholdPeak, 75.0);
      expect(frontRaise.formThreshold, 145.0);

      final jumpingJack = _loadConfig(
        'assets/config/exercises/jumping_jack.json',
      );
      expect(jumpingJack.thresholdNeutral, 20.0);
      expect(jumpingJack.thresholdActive, 55.0);
      expect(jumpingJack.thresholdPeak, 120.0);
      expect(jumpingJack.formThreshold, 95.0);
      expect(jumpingJack.targetMaxAngle, 130.0);
    });

    test('parses the seven-exercise range-rep expansion configs', () {
      const expectations = <String, (String, double, double, double)>{
        'assets/config/exercises/crunch.json': ('Crunch', 120, 112, 98),
        'assets/config/exercises/reverse_crunch.json': (
          'Reverse Crunch',
          105,
          92,
          68,
        ),
        'assets/config/exercises/bent_knee_leg_raise.json': (
          'Bent-Knee Leg Raise',
          125,
          110,
          78,
        ),
        'assets/config/exercises/standing_hamstring_curl.json': (
          'Standing Hamstring Curl',
          165,
          145,
          92,
        ),
        'assets/config/exercises/standing_hip_abduction.json': (
          'Standing Hip Abduction',
          170,
          155,
          128,
        ),
        'assets/config/exercises/overhead_triceps_extension.json': (
          'Overhead Triceps Extension',
          82,
          105,
          155,
        ),
        'assets/config/exercises/upright_row.json': ('Upright Row', 28, 40, 75),
      };

      for (final entry in expectations.entries) {
        final config = _loadConfig(entry.key);
        final expected = entry.value;
        expect(config.name, expected.$1, reason: entry.key);
        expect(config.thresholdNeutral, expected.$2, reason: entry.key);
        expect(config.thresholdActive, expected.$3, reason: entry.key);
        expect(config.thresholdPeak, expected.$4, reason: entry.key);
        expect(config.rangeRepSignals, isNotNull, reason: entry.key);
      }
    });

    test('parses the Good Morning hip-hinge config', () {
      final config = _loadConfig('assets/config/exercises/good_morning.json');

      expect(config.name, 'Good Morning');
      expect(config.primaryJoint, PoseLandmarkType.leftHip);
      expect(config.joint1, PoseLandmarkType.leftShoulder);
      expect(config.joint2, PoseLandmarkType.leftKnee);
      expect(config.thresholdNeutral, 165.0);
      expect(config.thresholdActive, 150.0);
      expect(config.thresholdPeak, 115.0);
      expect(config.formThreshold, 140.0);
      expect(config.rangeRepSignals, isNotNull);
    });

    test('parses wall-sit and side-plank hold configs', () {
      final wallSit = _loadConfig('assets/config/exercises/wall_sit.json');
      expect(wallSit.wallSitPosture, isNotNull);
      expect(wallSit.wallSitPosture?.activeKneeMaxAngle, 130.0);
      expect(wallSit.wallSitPosture?.kneeMinAngle, 80.0);
      expect(wallSit.wallSitPosture?.kneeMaxAngle, 120.0);
      expect(
        wallSit.holdSignals?.definitionFor(HoldSignal.kneeFlexion)?.middle,
        PoseLandmarkType.leftKnee,
      );
      expect(
        wallSit.holdSignals?.definitionFor(HoldSignal.torsoAlignment)?.middle,
        PoseLandmarkType.leftShoulder,
      );

      final sidePlank = _loadConfig('assets/config/exercises/side_plank.json');
      expect(sidePlank.holdPosture, isNotNull);
      expect(
        sidePlank.holdSignals?.definitionFor(HoldSignal.alignment)?.middle,
        PoseLandmarkType.leftHip,
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
      'keeps hollow hold threshold fallback behavior when thresholds are omitted',
      () {
        final config = ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Hollow Hold',
          'primaryJoint': 'leftHip',
          'joint1': 'leftShoulder',
          'joint2': 'leftAnkle',
          'hollowHoldPosture': <String, dynamic>{
            'activePostureMaxAngle': 170.0,
            'compressionEntryMaxAngle': 165.0,
            'compressionSustainMaxAngle': 169.0,
            'armExtensionMinAngle': 135.0,
            'kneeExtensionMinAngle': 165.0,
            'breakGraceMillis': 300,
          },
        });

        expect(config.thresholdNeutral, 170.0);
        expect(config.thresholdActive, 165.0);
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
      'rejects unknown hollow posture config keys with their parent path',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Hollow Hold',
            'primaryJoint': 'leftHip',
            'joint1': 'leftShoulder',
            'joint2': 'leftAnkle',
            'thresholdNeutral': 170.0,
            'thresholdActive': 165.0,
            'thresholdPeak': 0.0,
            'hollowHoldPosture': <String, dynamic>{
              'activePostureMaxAngle': 170.0,
              'compressionEntryMaxAngle': 165.0,
              'compressionSustainMaxAngle': 169.0,
              'armExtensionMinAngle': 135.0,
              'kneeExtensionMinAngle': 165.0,
              'breakGraceMillis': 300,
              'mystery': true,
            },
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              contains('ExerciseConfig.hollowHoldPosture'),
            ),
          ),
        );
      },
    );

    test(
      'includes the exact hollow hold signal path for invalid landmarks',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Hollow Hold',
            'primaryJoint': 'leftHip',
            'joint1': 'leftShoulder',
            'joint2': 'leftAnkle',
            'thresholdNeutral': 170.0,
            'thresholdActive': 165.0,
            'thresholdPeak': 0.0,
            'holdSignals': <String, dynamic>{
              'referenceSide': 'left',
              'compression': <String, dynamic>{
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
              contains('ExerciseConfig.holdSignals.compression.first'),
            ),
          ),
        );
      },
    );

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

    test(
      'includes the exact transform path for unsupported transform names',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Biceps Curl',
            'primaryJoint': 'leftElbow',
            'joint1': 'leftShoulder',
            'joint2': 'leftWrist',
            'thresholdNeutral': 155.0,
            'thresholdActive': 140.0,
            'thresholdPeak': 80.0,
            'rangeRepSignals': <String, dynamic>{
              'postureAngle': <String, dynamic>{
                'first': 'leftElbow',
                'middle': 'leftShoulder',
                'last': 'leftHip',
                'transform': 'flip360',
              },
            },
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              allOf(
                contains('RangeRepSignalTransform'),
                contains(
                  'ExerciseConfig.rangeRepSignals.postureAngle.transform',
                ),
              ),
            ),
          ),
        );
      },
    );

    test(
      'alias signal diagnostics truthfully describe the optional transform key',
      () {
        expect(
          () => ExerciseConfig.fromMap(<String, dynamic>{
            'name': 'Biceps Curl',
            'primaryJoint': 'leftElbow',
            'joint1': 'leftShoulder',
            'joint2': 'leftWrist',
            'thresholdNeutral': 155.0,
            'thresholdActive': 140.0,
            'thresholdPeak': 88.0,
            'rangeRepSignals': <String, dynamic>{
              'depthMetric': <String, dynamic>{
                'source': 'primaryMetric',
                'unexpected': true,
              },
            },
          }),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message.toString(),
              'message',
              allOf(
                contains(
                  'ExerciseConfig.rangeRepSignals.depthMetric only supports '
                  'the "source" key and optional "transform" key',
                ),
                isNot(contains('only supports the "source" key for alias')),
              ),
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
