import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const extractor = ExerciseMetricsExtractor();

  group('ExerciseMetricsExtractor', () {
    test('squat explicit config emits the expected form signals', () {
      final config = _loadConfig('assets/config/exercises/squat.json');
      final metrics = extractor.extract(
        _rangeRepPose(),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
      expect(metrics.leftRangeRepMetrics.hasFormMetric, isTrue);
      expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
      expect(metrics.leftRangeRepMetrics.formMetric, closeTo(90.0, 0.001));
      expect(
        metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
        closeTo(90.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.depthMetric,
        closeTo(90.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
        closeTo(135.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.lockoutMetric,
        closeTo(90.0, 0.001),
      );
    });

    test(
      'legacy squat config without rangeRepSignals keeps compatibility extraction',
      () {
        final config = ExerciseConfig.fromMap(<String, dynamic>{
          'name': 'Legacy Squat',
          'primaryJoint': 'leftKnee',
          'joint1': 'leftHip',
          'joint2': 'leftAnkle',
          'thresholdNeutral': 160.0,
          'thresholdActive': 150.0,
          'thresholdPeak': 95.0,
        });
        final metrics = extractor.extract(
          _rangeRepPose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.squat,
        );

        expect(config.usesLegacyRangeRepSignalFallback, isTrue);
        expect(
          metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          closeTo(135.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.lockoutMetric,
          closeTo(90.0, 0.001),
        );
      },
    );

    test(
      'optional signal stays null when it is supported by contract but not configured',
      () {
        final config = _futureTemplateConfig(includeAlignmentSignal: false);
        final contract = RangeRepContract(
          supportedPhases: const <RangeRepPhase>{
            RangeRepPhase.descending,
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          },
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.alignmentMetric,
          },
        );

        final metrics = extractor.extract(
          _futureTemplatePose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: contract,
        );

        expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
        expect(metrics.leftRangeRepMetrics.hasFormMetric, isTrue);
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          isNull,
        );
      },
    );

    test(
      'configured optional signal becomes null when its landmark is missing',
      () {
        final config = _loadConfig('assets/config/exercises/squat.json');
        final metrics = extractor.extract(
          _rangeRepPose(includeLeftAnkle: false),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.squat,
        );

        expect(
          metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          isNull,
        );
        expect(metrics.leftRangeRepMetrics.formSignals?.lockoutMetric, isNull);
      },
    );

    test(
      'configured signal is not emitted when the contract does not support it',
      () {
        final config = _loadConfig('assets/config/exercises/squat.json');
        final contract = RangeRepContract(
          supportedPhases: const <RangeRepPhase>{
            RangeRepPhase.descending,
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          },
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.depthMetric,
          },
        );

        final metrics = extractor.extract(
          _rangeRepPose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: contract,
        );

        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(90.0, 0.001),
        );
        expect(metrics.leftRangeRepMetrics.formSignals?.torsoAngle, isNull);
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          isNull,
        );
        expect(metrics.leftRangeRepMetrics.formSignals?.lockoutMetric, isNull);
      },
    );

    test(
      'left and right side substitution works for configured angle triples',
      () {
        final config = _futureTemplateConfig();
        final contract = RangeRepContract(
          supportedPhases: const <RangeRepPhase>{
            RangeRepPhase.descending,
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          },
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.alignmentMetric,
          },
        );

        final metrics = extractor.extract(
          _futureTemplatePose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: contract,
        );

        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
        expect(metrics.rightRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
        expect(metrics.leftRangeRepMetrics.formMetric, closeTo(90.0, 0.001));
        expect(metrics.rightRangeRepMetrics.formMetric, closeTo(90.0, 0.001));
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.rightRangeRepMetrics.formSignals?.alignmentMetric,
          closeTo(90.0, 0.001),
        );
      },
    );

    test('side confidence drops when required core landmarks are missing', () {
      final config = _loadConfig('assets/config/exercises/squat.json');
      final fullMetrics = extractor.extract(
        _rangeRepPose(),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );
      final missingMetrics = extractor.extract(
        _rangeRepPose(includeLeftKnee: false),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(
        fullMetrics.leftRangeRepMetrics.sideConfidence,
        greaterThan(missingMetrics.leftRangeRepMetrics.sideConfidence!),
      );
      expect(missingMetrics.leftRangeRepMetrics.hasPrimaryAngle, isFalse);
      expect(missingMetrics.leftRangeRepMetrics.hasFormMetric, isFalse);
    });

    test(
      'a test-only future template config works with a different primary joint triple',
      () {
        final config = _futureTemplateConfig();
        final contract = RangeRepContract(
          supportedPhases: const <RangeRepPhase>{
            RangeRepPhase.descending,
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          },
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.depthMetric,
            RangeRepSignal.alignmentMetric,
          },
        );

        final metrics = extractor.extract(
          _futureTemplatePose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: contract,
        );

        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
        expect(metrics.leftRangeRepMetrics.formMetric, closeTo(90.0, 0.001));
        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          closeTo(90.0, 0.001),
        );
      },
    );

    test('push-up synthetic pose emits the expected range-rep signals', () {
      final config = _loadConfig('assets/config/exercises/push_up.json');
      final metrics = extractor.extract(
        _pushUpPose(),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
      expect(metrics.leftRangeRepMetrics.hasFormMetric, isTrue);
      expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
      expect(metrics.leftRangeRepMetrics.formMetric, closeTo(180.0, 0.001));
      expect(
        metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
        closeTo(180.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.depthMetric,
        closeTo(90.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
        closeTo(180.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.lockoutMetric,
        closeTo(90.0, 0.001),
      );
    });

    test('push-up right-side substitution works', () {
      final config = _loadConfig('assets/config/exercises/push_up.json');
      final metrics = extractor.extract(
        _pushUpPose(),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(metrics.rightRangeRepMetrics.hasPrimaryAngle, isTrue);
      expect(metrics.rightRangeRepMetrics.hasFormMetric, isTrue);
      expect(metrics.rightRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
      expect(metrics.rightRangeRepMetrics.formMetric, closeTo(180.0, 0.001));
    });

    test('push-up safely degrades primary signal when wrist is missing', () {
      final config = _loadConfig('assets/config/exercises/push_up.json');
      final fullMetrics = extractor.extract(
        _pushUpPose(),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );
      final missingMetrics = extractor.extract(
        _pushUpPose(includeLeftWrist: false),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(missingMetrics.leftRangeRepMetrics.hasPrimaryAngle, isFalse);
      expect(
        missingMetrics.leftRangeRepMetrics.formMetric,
        closeTo(180.0, 0.001),
      );
      expect(
        missingMetrics.leftRangeRepMetrics.formSignals?.depthMetric,
        isNull,
      );
      expect(
        missingMetrics.leftRangeRepMetrics.formSignals?.lockoutMetric,
        isNull,
      );
      expect(
        fullMetrics.leftRangeRepMetrics.sideConfidence,
        greaterThan(missingMetrics.leftRangeRepMetrics.sideConfidence!),
      );
    });

    test('push-up missing ankle degrades posture signals without crashing', () {
      final config = _loadConfig('assets/config/exercises/push_up.json');
      final metrics = extractor.extract(
        _pushUpPose(includeLeftAnkle: false),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
      expect(metrics.leftRangeRepMetrics.hasFormMetric, isFalse);
      expect(metrics.leftRangeRepMetrics.formSignals?.torsoAngle, isNull);
      expect(metrics.leftRangeRepMetrics.formSignals?.alignmentMetric, isNull);
      expect(
        metrics.leftRangeRepMetrics.formSignals?.depthMetric,
        closeTo(90.0, 0.001),
      );
      expect(
        metrics.leftRangeRepMetrics.formSignals?.lockoutMetric,
        closeTo(90.0, 0.001),
      );
    });

    test(
      'push-up suppresses configured signals that the contract does not support',
      () {
        final config = _loadConfig('assets/config/exercises/push_up.json');
        final contract = RangeRepContract(
          supportedPhases: const <RangeRepPhase>{
            RangeRepPhase.descending,
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          },
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.postureAngle,
            RangeRepSignal.depthMetric,
          },
        );

        final metrics = extractor.extract(
          _pushUpPose(),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: contract,
        );

        expect(
          metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
          closeTo(180.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          isNull,
        );
        expect(metrics.leftRangeRepMetrics.formSignals?.lockoutMetric, isNull);
      },
    );

    test(
      'sit-up left-side extraction emits independent primary and form metrics',
      () {
        final config = _loadConfig('assets/config/exercises/sit_up.json');
        final metrics = extractor.extract(
          buildSitUpPose(
            primaryAngle: 90,
            formAngle: 120,
            includeRightSide: false,
          ),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
        );

        expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
        expect(metrics.leftRangeRepMetrics.hasFormMetric, isTrue);
        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
        expect(metrics.leftRangeRepMetrics.formMetric, closeTo(120.0, 0.001));
        expect(
          metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
          closeTo(120.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.alignmentMetric,
          isNull,
        );
        expect(metrics.leftRangeRepMetrics.formSignals?.lockoutMetric, isNull);
      },
    );

    test('sit-up right-side mirroring uses the existing resolver path', () {
      final config = _loadConfig('assets/config/exercises/sit_up.json');
      final metrics = extractor.extract(
        buildSitUpPose(primaryAngle: 85, formAngle: 125),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(metrics.rightRangeRepMetrics.hasPrimaryAngle, isTrue);
      expect(metrics.rightRangeRepMetrics.hasFormMetric, isTrue);
      expect(metrics.rightRangeRepMetrics.primaryAngle, closeTo(85.0, 0.001));
      expect(metrics.rightRangeRepMetrics.formMetric, closeTo(125.0, 0.001));
    });

    test(
      'sit-up primary and form metrics do not collapse onto the same signal',
      () {
        final config = _loadConfig('assets/config/exercises/sit_up.json');
        final metrics = extractor.extract(
          buildSitUpPose(
            primaryAngle: 82,
            formAngle: 130,
            includeRightSide: false,
          ),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
        );

        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(82.0, 0.001));
        expect(metrics.leftRangeRepMetrics.formMetric, closeTo(130.0, 0.001));
        expect(
          metrics.leftRangeRepMetrics.primaryAngle,
          isNot(closeTo(metrics.leftRangeRepMetrics.formMetric, 0.001)),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(82.0, 0.001),
        );
        expect(
          metrics.leftRangeRepMetrics.formSignals?.torsoAngle,
          closeTo(130.0, 0.001),
        );
      },
    );

    group('hold metrics', () {
      test(
        'valid left plank geometry emits expected hold angles and preserves pose metadata',
        () {
          final pose = _holdPose();
          final metrics = extractor.extract(
            pose,
            _holdConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.left,
          );

          expect(metrics.bodyLineAngle, closeTo(180.0, 0.001));
          expect(metrics.armSupportAngle, closeTo(90.0, 0.001));
          expect(metrics.legExtensionAngle, closeTo(180.0, 0.001));
          expect(metrics.holdSide, HoldSide.left);
          expect(metrics.hasPose, isTrue);
          expect(metrics.landmarks, hasLength(pose.landmarks.length));
        },
      );

      test('hold metrics are only emitted for the hold engine', () {
        final metrics = extractor.extract(
          _holdPose(),
          _holdConfig(),
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.squat,
        );

        expect(metrics.bodyLineAngle, isNull);
        expect(metrics.armSupportAngle, isNull);
        expect(metrics.legExtensionAngle, isNull);
      });

      for (final scenario
          in <
            ({
              PoseLandmarkType missingLandmark,
              String name,
              bool hasBodyLineAngle,
              bool hasArmSupportAngle,
              bool hasLegExtensionAngle,
            })
          >[
            (
              missingLandmark: PoseLandmarkType.leftElbow,
              name: 'missing left elbow only clears arm support extraction',
              hasBodyLineAngle: true,
              hasArmSupportAngle: false,
              hasLegExtensionAngle: true,
            ),
            (
              missingLandmark: PoseLandmarkType.leftKnee,
              name: 'missing left knee only clears leg extension extraction',
              hasBodyLineAngle: true,
              hasArmSupportAngle: true,
              hasLegExtensionAngle: false,
            ),
            (
              missingLandmark: PoseLandmarkType.leftAnkle,
              name:
                  'missing left ankle clears body line and leg extension extraction',
              hasBodyLineAngle: false,
              hasArmSupportAngle: true,
              hasLegExtensionAngle: false,
            ),
            (
              missingLandmark: PoseLandmarkType.leftShoulder,
              name:
                  'missing left shoulder clears body line and arm support extraction',
              hasBodyLineAngle: false,
              hasArmSupportAngle: false,
              hasLegExtensionAngle: true,
            ),
          ]) {
        test(scenario.name, () {
          final metrics = extractor.extract(
            _holdPose(
              missingLandmarks: <PoseLandmarkType>{scenario.missingLandmark},
            ),
            _holdConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.left,
          );

          expect(metrics.bodyLineAngle != null, scenario.hasBodyLineAngle);
          expect(metrics.armSupportAngle != null, scenario.hasArmSupportAngle);
          expect(
            metrics.legExtensionAngle != null,
            scenario.hasLegExtensionAngle,
          );
        });
      }

      test(
        'right-only hold extraction derives metrics from the right side',
        () {
          final metrics = extractor.extract(
            _holdPose(rightOnly: true),
            _holdConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.right,
          );

          expect(metrics.bodyLineAngle, closeTo(180.0, 0.001));
          expect(metrics.armSupportAngle, closeTo(90.0, 0.001));
          expect(metrics.legExtensionAngle, closeTo(180.0, 0.001));
          expect(metrics.holdSide, HoldSide.right);
        },
      );

      test(
        'hold metrics follow test-only configured signal geometry instead of hardcoded plank triplets',
        () {
          final metrics = extractor.extract(
            _alternateHoldPose(),
            _alternateHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.left,
          );

          expect(metrics.bodyLineAngle, closeTo(90.0, 0.001));
          expect(metrics.armSupportAngle, closeTo(90.0, 0.001));
          expect(metrics.legExtensionAngle, closeTo(180.0, 0.001));
        },
      );

      test(
        'hold metrics mirror mixed-side configured geometry for the right side',
        () {
          final metrics = extractor.extract(
            _alternateHoldPose(rightOnly: true),
            _alternateHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.right,
          );

          expect(metrics.bodyLineAngle, closeTo(90.0, 0.001));
          expect(metrics.armSupportAngle, closeTo(90.0, 0.001));
          expect(metrics.legExtensionAngle, closeTo(180.0, 0.001));
          expect(metrics.holdSide, HoldSide.right);
        },
      );
    });
  });
}

ExerciseConfig _loadConfig(String path) {
  final rawJson = File(path).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
}

ExerciseConfig _futureTemplateConfig({bool includeAlignmentSignal = true}) {
  final rangeRepSignals = <String, dynamic>{
    'postureAngle': <String, dynamic>{
      'first': 'leftShoulder',
      'middle': 'leftElbow',
      'last': 'leftWrist',
    },
    'depthMetric': <String, dynamic>{'source': 'primaryMetric'},
  };
  if (includeAlignmentSignal) {
    rangeRepSignals['alignmentMetric'] = <String, dynamic>{
      'first': 'leftHip',
      'middle': 'leftShoulder',
      'last': 'leftWrist',
    };
  }

  return ExerciseConfig.fromMap(<String, dynamic>{
    'name': 'Template Curl',
    'primaryJoint': 'leftElbow',
    'joint1': 'leftShoulder',
    'joint2': 'leftWrist',
    'thresholdNeutral': 160.0,
    'thresholdActive': 120.0,
    'thresholdPeak': 75.0,
    'rangeRepSignals': rangeRepSignals,
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
    holdSignals: const HoldSignalExtractionConfig(
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
    holdSignals: const HoldSignalExtractionConfig(
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

Pose _rangeRepPose({
  bool includeLeftKnee = true,
  bool includeLeftAnkle = true,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      0,
      2,
    ),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 0, 1),
    if (includeLeftKnee)
      PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 1, 1),
    if (includeLeftAnkle)
      PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 1, 0),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      4,
      2,
    ),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 4, 1),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 3, 1),
    PoseLandmarkType.rightAnkle: _landmark(PoseLandmarkType.rightAnkle, 3, 0),
  };

  return Pose(landmarks: landmarks);
}

Pose _futureTemplatePose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
      ),
      PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 0, 1),
      PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 1, 1),
      PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, -1, 1),
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        4,
        2,
      ),
      PoseLandmarkType.rightElbow: _landmark(PoseLandmarkType.rightElbow, 4, 1),
      PoseLandmarkType.rightWrist: _landmark(PoseLandmarkType.rightWrist, 3, 1),
      PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 5, 1),
    },
  );
}

Pose _pushUpPose({bool includeLeftWrist = true, bool includeLeftAnkle = true}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      0,
      2,
    ),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 1, 2),
    if (includeLeftWrist)
      PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 1, 1),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 2, 2),
    if (includeLeftAnkle)
      PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 4, 2),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      10,
      2,
    ),
    PoseLandmarkType.rightElbow: _landmark(PoseLandmarkType.rightElbow, 9, 2),
    PoseLandmarkType.rightWrist: _landmark(PoseLandmarkType.rightWrist, 9, 1),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 8, 2),
    PoseLandmarkType.rightAnkle: _landmark(PoseLandmarkType.rightAnkle, 6, 2),
  };

  return Pose(landmarks: landmarks);
}

Pose _holdPose({
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  final landmarks = Map<PoseLandmarkType, PoseLandmark>.from(
    rightOnly ? _rightHoldLandmarks() : _leftHoldLandmarks(),
  );
  for (final landmarkType in missingLandmarks) {
    landmarks.remove(landmarkType);
  }
  return Pose(landmarks: landmarks);
}

Pose _alternateHoldPoseForSide(HoldSide side) {
  final landmarks = side == HoldSide.left
      ? <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.leftShoulder: _landmark(
            PoseLandmarkType.leftShoulder,
            0,
            1,
          ),
          PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 0, 0),
          PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 1, 0),
          PoseLandmarkType.leftElbow: _landmark(
            PoseLandmarkType.leftElbow,
            1,
            0,
          ),
          PoseLandmarkType.leftWrist: _landmark(
            PoseLandmarkType.leftWrist,
            1,
            1,
          ),
          PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 1, 0),
          PoseLandmarkType.leftAnkle: _landmark(
            PoseLandmarkType.leftAnkle,
            2,
            -1,
          ),
        }
      : <PoseLandmarkType, PoseLandmark>{
          PoseLandmarkType.rightShoulder: _landmark(
            PoseLandmarkType.rightShoulder,
            0,
            1,
          ),
          PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 0, 0),
          PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, -1, 0),
          PoseLandmarkType.rightElbow: _landmark(
            PoseLandmarkType.rightElbow,
            -1,
            0,
          ),
          PoseLandmarkType.rightWrist: _landmark(
            PoseLandmarkType.rightWrist,
            -1,
            1,
          ),
          PoseLandmarkType.rightKnee: _landmark(
            PoseLandmarkType.rightKnee,
            -1,
            0,
          ),
          PoseLandmarkType.rightAnkle: _landmark(
            PoseLandmarkType.rightAnkle,
            -2,
            -1,
          ),
        };

  return Pose(landmarks: landmarks);
}

Pose _alternateHoldPose({bool rightOnly = false}) {
  return Pose(
    landmarks: rightOnly
        ? _alternateHoldPoseForSide(HoldSide.right).landmarks
        : _alternateHoldPoseForSide(HoldSide.left).landmarks,
  );
}

Map<PoseLandmarkType, PoseLandmark> _leftHoldLandmarks() {
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      -1,
      0,
    ),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, -0.5, 0),
    PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, -0.5, -1),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 0, 0),
    PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 0.5, 0),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 1, 0),
  };
}

Map<PoseLandmarkType, PoseLandmark> _rightHoldLandmarks() {
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      1,
      0,
    ),
    PoseLandmarkType.rightElbow: _landmark(PoseLandmarkType.rightElbow, 0.5, 0),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      0.5,
      -1,
    ),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 0, 0),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, -0.5, 0),
    PoseLandmarkType.rightAnkle: _landmark(PoseLandmarkType.rightAnkle, -1, 0),
  };
}

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 1.0);
}
