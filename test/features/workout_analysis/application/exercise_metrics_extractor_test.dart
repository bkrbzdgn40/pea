import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

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

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 1.0);
}
