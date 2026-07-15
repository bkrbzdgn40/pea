import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const factory = AnalysisEngineFactory();
  final squatConfig = ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
  );
  final pushUpConfig = ExerciseConfig(
    name: 'Push-Up',
    primaryJoint: PoseLandmarkType.leftElbow,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftWrist,
    thresholdNeutral: 165.0,
    thresholdActive: 135.0,
    thresholdPeak: 95.0,
  );
  final plankConfig = _holdConfig();

  group('AnalysisEngineFactory', () {
    test('rejects range-rep creation without a contract', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.rangeRep,
          config: squatConfig,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('rangeRepContract'),
          ),
        ),
      );
    });

    test('accepts the squat range-rep contract', () {
      final RangeRepAnalysisEngine engine = factory.createRangeRep(
        config: squatConfig,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test('accepts the push-up range-rep contract', () {
      final RangeRepAnalysisEngine engine = factory.createRangeRep(
        config: pushUpConfig,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test('rejects hold creation without a contract', () {
      expect(
        () => factory.create(engineKind: EngineKind.hold, config: plankConfig),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('holdContract'),
          ),
        ),
      );
    });

    test('rejects hold creation without holdSignals config', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.hold,
          config: _holdConfig(includeHoldSignals: false),
          holdContract: HoldContracts.plankFamily,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('holdSignals'),
          ),
        ),
      );
    });

    for (final scenario in <({HoldSignal signal, ExerciseConfig config})>[
      (
        signal: HoldSignal.alignment,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.alignment}),
      ),
      (
        signal: HoldSignal.support,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.support}),
      ),
      (
        signal: HoldSignal.extension,
        config: _holdConfig(missingSignals: <HoldSignal>{HoldSignal.extension}),
      ),
    ]) {
      test('rejects hold creation when ${scenario.signal.name} is missing', () {
        expect(
          () => factory.create(
            engineKind: EngineKind.hold,
            config: scenario.config,
            holdContract: HoldContracts.plankFamily,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains(scenario.signal.name),
            ),
          ),
        );
      });
    }

    test('creates a hold engine for a valid plank contract and config', () {
      final HoldAnalysisEngine engine = factory.createHold(
        config: plankConfig,
        holdContract: HoldContracts.plankFamily,
      );

      expect(engine, isA<HoldEngine>());
    });

    test('keeps alternating-rep unimplemented', () {
      expect(
        () => factory.create(
          engineKind: EngineKind.alternatingRep,
          config: squatConfig,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('alternatingRep'),
          ),
        ),
      );
    });
  });
}

ExerciseConfig _holdConfig({
  bool includeHoldSignals = true,
  Set<HoldSignal> missingSignals = const <HoldSignal>{},
}) {
  final holdSignals = includeHoldSignals
      ? HoldSignalExtractionConfig(
          referenceSide: HoldSide.left,
          alignment: missingSignals.contains(HoldSignal.alignment)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftShoulder,
                  middle: PoseLandmarkType.leftHip,
                  last: PoseLandmarkType.leftAnkle,
                ),
          support: missingSignals.contains(HoldSignal.support)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftShoulder,
                  middle: PoseLandmarkType.leftElbow,
                  last: PoseLandmarkType.leftWrist,
                ),
          extension: missingSignals.contains(HoldSignal.extension)
              ? null
              : const PoseAngleLandmarks(
                  first: PoseLandmarkType.leftHip,
                  middle: PoseLandmarkType.leftKnee,
                  last: PoseLandmarkType.leftAnkle,
                ),
        )
      : null;

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
    holdSignals: holdSignals,
  );
}
