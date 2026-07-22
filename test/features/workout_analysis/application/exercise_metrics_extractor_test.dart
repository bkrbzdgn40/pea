import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
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
          signalRoles: _testRangeRepSignalRoles(const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.alignmentMetric,
          }),
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
          signalRoles: _testRangeRepSignalRoles(const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.depthMetric,
          }),
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
          signalRoles: _testRangeRepSignalRoles(const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.alignmentMetric,
          }),
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
          signalRoles: _testRangeRepSignalRoles(const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.depthMetric,
            RangeRepSignal.alignmentMetric,
          }),
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
          signalRoles: _testRangeRepSignalRoles(const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
            RangeRepSignal.formMetric,
            RangeRepSignal.postureAngle,
            RangeRepSignal.depthMetric,
          }),
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

    test(
      'sit-up still keeps the primary metric when the advisory ankle removes only the form metric',
      () {
        final config = _loadConfig('assets/config/exercises/sit_up.json');
        final metrics = extractor.extract(
          buildSitUpPose(
            primaryAngle: 82,
            formAngle: 130,
            includeRightSide: false,
            missingLandmarks: const <PoseLandmarkType>{
              PoseLandmarkType.leftAnkle,
            },
          ),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.sitUp,
        );

        expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(82.0, 0.001));
        expect(metrics.leftRangeRepMetrics.hasFormMetric, isFalse);
        expect(metrics.leftRangeRepMetrics.formSignals?.torsoAngle, isNull);
        expect(
          metrics.leftRangeRepMetrics.formSignals?.depthMetric,
          closeTo(82.0, 0.001),
        );
      },
    );

    group('biceps curl bilateral metrics', () {
      test(
        'extracts left and right elbow primary angles without side mix-up',
        () {
          final config = _loadConfig(
            'assets/config/exercises/biceps_curl.json',
          );
          final metrics = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 82, rightPrimaryAngle: 104),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );

          expect(
            metrics.leftRangeRepMetrics.primaryAngle,
            closeTo(82.0, 0.001),
          );
          expect(
            metrics.rightRangeRepMetrics.primaryAngle,
            closeTo(104.0, 0.001),
          );
          expect(
            metrics.leftRangeRepMetrics.primaryAngle,
            isNot(closeTo(metrics.rightRangeRepMetrics.primaryAngle, 0.001)),
          );
        },
      );

      test(
        'complement180 posture transform preserves configured upper-arm scores on both sides',
        () {
          final config = _loadConfig(
            'assets/config/exercises/biceps_curl.json',
          );
          final metrics = extractor.extract(
            buildBicepsCurlPose(
              leftPrimaryAngle: 90,
              rightPrimaryAngle: 90,
              leftUpperArmDriftAngle: 20,
              rightUpperArmDriftAngle: 35,
            ),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );

          expect(metrics.leftRangeRepMetrics.formMetric, closeTo(160.0, 0.001));
          expect(
            metrics.rightRangeRepMetrics.formMetric,
            closeTo(145.0, 0.001),
          );
        },
      );

      test(
        'bilateral primary metric only crosses neutral when both arms are neutral',
        () {
          final config = _loadConfig(
            'assets/config/exercises/biceps_curl.json',
          );
          final bothNeutral = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 162),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final leftOnlyNeutral = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 132),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final rightOnlyNeutral = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 132, rightPrimaryAngle: 160),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );

          expect(
            bothNeutral.bilateralRangeRepMetrics?.primaryAngle,
            greaterThan(config.thresholdNeutral),
          );
          expect(
            leftOnlyNeutral.bilateralRangeRepMetrics?.primaryAngle,
            equals(config.thresholdNeutral),
          );
          expect(
            rightOnlyNeutral.bilateralRangeRepMetrics?.primaryAngle,
            equals(config.thresholdNeutral),
          );
        },
      );

      test(
        'bilateral primary metric waits for the lagging arm before exposing peak and return',
        () {
          final config = _loadConfig(
            'assets/config/exercises/biceps_curl.json',
          );
          final earlyPeak = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 72, rightPrimaryAngle: 92),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final bothPeak = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 72, rightPrimaryAngle: 78),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final earlyReturn = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 120),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final fullReturn = extractor.extract(
            buildBicepsCurlPose(leftPrimaryAngle: 160, rightPrimaryAngle: 158),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );

          expect(
            earlyPeak.bilateralRangeRepMetrics?.primaryAngle,
            closeTo(92.0, 0.001),
          );
          expect(
            bothPeak.bilateralRangeRepMetrics?.primaryAngle,
            closeTo(78.0, 0.001),
          );
          expect(
            earlyReturn.bilateralRangeRepMetrics?.primaryAngle,
            equals(config.thresholdNeutral),
          );
          expect(
            fullReturn.bilateralRangeRepMetrics?.primaryAngle,
            greaterThan(config.thresholdNeutral),
          );
        },
      );

      test('sync score decreases as left-right elbow timing diverges', () {
        final config = _loadConfig('assets/config/exercises/biceps_curl.json');
        final inSync = extractor.extract(
          buildBicepsCurlPose(leftPrimaryAngle: 90, rightPrimaryAngle: 90),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.bicepsCurl,
        );
        final outOfSync = extractor.extract(
          buildBicepsCurlPose(leftPrimaryAngle: 90, rightPrimaryAngle: 120),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.bicepsCurl,
        );

        expect(
          inSync.bilateralRangeRepMetrics?.syncScore,
          closeTo(180.0, 0.001),
        );
        expect(
          outOfSync.bilateralRangeRepMetrics?.syncScore,
          closeTo(150.0, 0.001),
        );
      });

      test(
        'biceps bilateral form metric reflects the worse arm but not sync jitter',
        () {
          final config = _loadConfig(
            'assets/config/exercises/biceps_curl.json',
          );
          final leftFormWorst = extractor.extract(
            buildBicepsCurlPose(
              leftPrimaryAngle: 90,
              rightPrimaryAngle: 90,
              leftUpperArmDriftAngle: 40,
              rightUpperArmDriftAngle: 20,
            ),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final rightFormWorst = extractor.extract(
            buildBicepsCurlPose(
              leftPrimaryAngle: 90,
              rightPrimaryAngle: 90,
              leftUpperArmDriftAngle: 20,
              rightUpperArmDriftAngle: 45,
            ),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );
          final syncWorst = extractor.extract(
            buildBicepsCurlPose(
              leftPrimaryAngle: 90,
              rightPrimaryAngle: 130,
              leftUpperArmDriftAngle: 20,
              rightUpperArmDriftAngle: 20,
            ),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.bicepsCurl,
          );

          expect(
            leftFormWorst.bilateralRangeRepMetrics?.leftFormScore,
            closeTo(140.0, 0.001),
          );
          expect(
            leftFormWorst.bilateralRangeRepMetrics?.formMetric,
            closeTo(140.0, 0.001),
          );
          expect(
            rightFormWorst.bilateralRangeRepMetrics?.rightFormScore,
            closeTo(135.0, 0.001),
          );
          expect(
            rightFormWorst.bilateralRangeRepMetrics?.formMetric,
            closeTo(135.0, 0.001),
          );
          expect(
            syncWorst.bilateralRangeRepMetrics?.syncScore,
            closeTo(140.0, 0.001),
          );
          expect(
            syncWorst.bilateralRangeRepMetrics?.formMetric,
            closeTo(160.0, 0.001),
          );
        },
      );
    });

    group('increasing-direction bilateral metrics', () {
      test('lateral raise waits for the lagging shoulder angle', () {
        final config = _loadConfig(
          'assets/config/exercises/lateral_raise.json',
        );
        final metrics = extractor.extract(
          _lateralRaisePose(leftShoulderAngle: 90, rightShoulderAngle: 45),
          config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.lateralRaise,
        );

        expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(90.0, 0.001));
        expect(metrics.rightRangeRepMetrics.primaryAngle, closeTo(45.0, 0.001));
        expect(
          metrics.bilateralRangeRepMetrics?.primaryAngle,
          closeTo(45.0, 0.001),
        );
        expect(
          metrics.bilateralRangeRepMetrics?.syncScore,
          closeTo(135.0, 0.001),
        );
      });

      test(
        'lateral raise preserves natural bilateral neutral below 32 degrees',
        () {
          final config = _loadConfig(
            'assets/config/exercises/lateral_raise.json',
          );
          final metrics = extractor.extract(
            _lateralRaisePose(leftShoulderAngle: 31, rightShoulderAngle: 29),
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.lateralRaise,
          );

          expect(config.thresholdNeutral, 32.0);
          expect(
            metrics.bilateralRangeRepMetrics?.primaryAngle,
            closeTo(29.0, 0.001),
          );
          expect(
            metrics.bilateralRangeRepMetrics!.primaryAngle,
            lessThan(config.thresholdNeutral),
          );
        },
      );
    });

    test('jumping jack exposes synchronized bilateral arm and leg signals', () {
      final config = _loadConfig('assets/config/exercises/jumping_jack.json');
      final metrics = extractor.extract(
        _jumpingJackPose(leftShoulderAngle: 120, rightShoulderAngle: 100),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.jumpingJack,
      );

      expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(120.0, 0.001));
      expect(metrics.rightRangeRepMetrics.primaryAngle, closeTo(100.0, 0.001));
      expect(
        metrics.bilateralRangeRepMetrics?.primaryAngle,
        closeTo(100.0, 0.001),
      );
      expect(
        metrics.bilateralRangeRepMetrics?.formMetric,
        closeTo(135.0, 0.001),
      );
    });

    group('hold metrics', () {
      test('wall sit extracts knee, hip, and torso hold signals', () {
        final config = _loadConfig('assets/config/exercises/wall_sit.json');
        final metrics = extractor.extract(
          _wallSitPose(),
          config,
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.wallSit,
          holdSide: HoldSide.left,
        );

        expect(
          metrics.holdSignalValues.valueFor(HoldSignal.kneeFlexion),
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.holdSignalValues.valueFor(HoldSignal.hipFlexion),
          closeTo(90.0, 0.001),
        );
        expect(
          metrics.holdSignalValues.valueFor(HoldSignal.torsoAlignment),
          closeTo(180.0, 0.001),
        );
      });

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

      test('hold extraction follows contract.requiredSignals', () {
        final metrics = extractor.extract(
          _holdPose(),
          _holdConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContract(
            family: HoldAnalysisFamily.plank,
            requiredSignals: const <HoldSignal>{
              HoldSignal.alignment,
              HoldSignal.support,
            },
            signalRoles: _testHoldSignalRoles(const <HoldSignal>{
              HoldSignal.alignment,
              HoldSignal.support,
            }),
          ),
          holdSide: HoldSide.left,
        );

        expect(metrics.bodyLineAngle, closeTo(180.0, 0.001));
        expect(metrics.armSupportAngle, closeTo(90.0, 0.001));
        expect(metrics.legExtensionAngle, isNull);
        expect(
          metrics.holdSignalValues.hasValue(HoldSignal.extension),
          isFalse,
        );
      });

      test(
        'hollow hold left-side extraction emits the expected canonical signals',
        () {
          final metrics = extractor.extract(
            buildHollowHoldPose(includeRightSide: false),
            buildHollowHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.hollowHold,
            holdSide: HoldSide.left,
          );

          expect(metrics.holdSide, HoldSide.left);
          expect(
            metrics.holdSignalValues.asMap().keys,
            unorderedEquals(<HoldSignal>{
              HoldSignal.compression,
              HoldSignal.armExtension,
              HoldSignal.kneeExtension,
            }),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.compression),
            closeTo(150.0, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.armExtension),
            closeTo(160.0, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.kneeExtension),
            closeTo(170.0, 0.001),
          );
          expect(
            metrics.holdSignalValues.hasValue(HoldSignal.alignment),
            isFalse,
          );
          expect(metrics.bodyLineAngle, isNull);
          expect(metrics.armSupportAngle, isNull);
          expect(metrics.legExtensionAngle, isNull);
        },
      );

      test(
        'hollow hold right-side extraction mirrors the configured triplets',
        () {
          final metrics = extractor.extract(
            buildHollowHoldPose(includeLeftSide: false),
            buildHollowHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.hollowHold,
            holdSide: HoldSide.right,
          );

          expect(metrics.holdSide, HoldSide.right);
          expect(
            metrics.holdSignalValues.asMap().keys,
            unorderedEquals(<HoldSignal>{
              HoldSignal.compression,
              HoldSignal.armExtension,
              HoldSignal.kneeExtension,
            }),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.compression),
            closeTo(150.0, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.armExtension),
            closeTo(160.0, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.kneeExtension),
            closeTo(170.0, 0.001),
          );
        },
      );

      test(
        'characterizes a low and long hollow hold with real landmark coordinates',
        () {
          final metrics = extractor.extract(
            _characterizedLowLongHollowHoldPose(),
            buildHollowHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.hollowHold,
            holdSide: HoldSide.left,
          );

          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.compression),
            closeTo(164.291, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.armExtension),
            closeTo(136.302, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.kneeExtension),
            closeTo(173.0, 0.001),
          );
        },
      );

      test(
        'characterizes a more-compressed hollow hold with real landmark coordinates',
        () {
          final metrics = extractor.extract(
            _characterizedCompressedHollowHoldPose(),
            buildHollowHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.hollowHold,
            holdSide: HoldSide.left,
          );

          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.compression),
            closeTo(151.04, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.armExtension),
            closeTo(136.302, 0.001),
          );
          expect(
            metrics.holdSignalValues.valueFor(HoldSignal.kneeExtension),
            closeTo(166.0, 0.001),
          );
        },
      );

      test('missing required hold signal config still fails', () {
        final config = ExerciseConfig(
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
          ),
        );

        expect(
          () => extractor.extract(
            _holdPose(),
            config,
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
            holdSide: HoldSide.left,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(HoldSignal.extension.name),
            ),
          ),
        );
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

Map<RangeRepSignal, Set<AnalysisSignalRole>> _testRangeRepSignalRoles(
  Iterable<RangeRepSignal> signals,
) {
  return <RangeRepSignal, Set<AnalysisSignalRole>>{
    for (final signal in signals)
      signal: <AnalysisSignalRole>{AnalysisSignalRole.detection},
  };
}

Map<HoldSignal, Set<AnalysisSignalRole>> _testHoldSignalRoles(
  Iterable<HoldSignal> signals,
) {
  return <HoldSignal, Set<AnalysisSignalRole>>{
    for (final signal in signals)
      signal: <AnalysisSignalRole>{AnalysisSignalRole.detection},
  };
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

Pose _lateralRaisePose({
  required double leftShoulderAngle,
  required double rightShoulderAngle,
}) {
  PoseLandmark point(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  final leftRadians = leftShoulderAngle * math.pi / 180.0;
  final rightRadians = rightShoulderAngle * math.pi / 180.0;
  final leftShoulder = const math.Point<double>(0, 0);
  final rightShoulder = const math.Point<double>(4, 0);
  final leftElbow = math.Point<double>(
    leftShoulder.x + math.sin(leftRadians),
    leftShoulder.y + math.cos(leftRadians),
  );
  final rightElbow = math.Point<double>(
    rightShoulder.x - math.sin(rightRadians),
    rightShoulder.y + math.cos(rightRadians),
  );
  final leftWrist = math.Point<double>(
    2 * leftElbow.x - leftShoulder.x,
    2 * leftElbow.y - leftShoulder.y,
  );
  final rightWrist = math.Point<double>(
    2 * rightElbow.x - rightShoulder.x,
    2 * rightElbow.y - rightShoulder.y,
  );

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: point(
        PoseLandmarkType.leftShoulder,
        leftShoulder.x,
        leftShoulder.y,
      ),
      PoseLandmarkType.leftElbow: point(
        PoseLandmarkType.leftElbow,
        leftElbow.x,
        leftElbow.y,
      ),
      PoseLandmarkType.leftWrist: point(
        PoseLandmarkType.leftWrist,
        leftWrist.x,
        leftWrist.y,
      ),
      PoseLandmarkType.leftHip: point(PoseLandmarkType.leftHip, 0, 1),
      PoseLandmarkType.rightShoulder: point(
        PoseLandmarkType.rightShoulder,
        rightShoulder.x,
        rightShoulder.y,
      ),
      PoseLandmarkType.rightElbow: point(
        PoseLandmarkType.rightElbow,
        rightElbow.x,
        rightElbow.y,
      ),
      PoseLandmarkType.rightWrist: point(
        PoseLandmarkType.rightWrist,
        rightWrist.x,
        rightWrist.y,
      ),
      PoseLandmarkType.rightHip: point(PoseLandmarkType.rightHip, 4, 1),
    },
  );
}

Pose _jumpingJackPose({
  required double leftShoulderAngle,
  required double rightShoulderAngle,
}) {
  final leftRadians = leftShoulderAngle * math.pi / 180.0;
  final rightRadians = rightShoulderAngle * math.pi / 180.0;
  const leftShoulder = math.Point<double>(-1, 0);
  const rightShoulder = math.Point<double>(1, 0);
  const leftHip = math.Point<double>(-1, 1);
  const rightHip = math.Point<double>(1, 1);

  final leftElbow = math.Point<double>(
    leftShoulder.x + math.sin(leftRadians),
    leftShoulder.y + math.cos(leftRadians),
  );
  final rightElbow = math.Point<double>(
    rightShoulder.x - math.sin(rightRadians),
    rightShoulder.y + math.cos(rightRadians),
  );
  const diagonal = 0.7071067811865476;
  const leftKnee = math.Point<double>(-1 - diagonal, 1 + diagonal);
  const rightKnee = math.Point<double>(1 + diagonal, 1 + diagonal);

  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        leftShoulder.x,
        leftShoulder.y,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        leftElbow.x,
        leftElbow.y,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        leftHip.x,
        leftHip.y,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        leftKnee.x,
        leftKnee.y,
      ),
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        rightShoulder.x,
        rightShoulder.y,
      ),
      PoseLandmarkType.rightElbow: _landmark(
        PoseLandmarkType.rightElbow,
        rightElbow.x,
        rightElbow.y,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        rightHip.x,
        rightHip.y,
      ),
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        rightKnee.x,
        rightKnee.y,
      ),
    },
  );
}

Pose _wallSitPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftEar: _landmark(PoseLandmarkType.leftEar, -2, 0),
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        -1,
        0,
      ),
      PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 0, 0),
      PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 0, 1),
      PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 1, 1),
    },
  );
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

Pose _characterizedLowLongHollowHoldPose() {
  return buildHollowHoldPoseFromCoordinates(
    shoulder: const math.Point<double>(-1.0, 0.2),
    hip: const math.Point<double>(0.0, 0.0),
    wrist: const math.Point<double>(-1.7, 1.2),
    ankle: const math.Point<double>(1.3, 0.1),
    kneeExtensionAngle: 173.0,
  );
}

Pose _characterizedCompressedHollowHoldPose() {
  return buildHollowHoldPoseFromCoordinates(
    shoulder: const math.Point<double>(-1.0, 0.2),
    hip: const math.Point<double>(0.0, 0.0),
    wrist: const math.Point<double>(-1.7, 1.2),
    ankle: const math.Point<double>(1.1, 0.35),
    kneeExtensionAngle: 166.0,
  );
}
