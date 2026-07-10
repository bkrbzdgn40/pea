import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
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
      final engine = factory.create(
        engineKind: EngineKind.rangeRep,
        config: squatConfig,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(engine, isA<RangeRepEngine>());
    });

    test('hold engine creation remains unaffected', () {
      final engine = factory.create(
        engineKind: EngineKind.hold,
        config: squatConfig,
      );

      expect(engine, isA<HoldEngine>());
    });
  });
}
