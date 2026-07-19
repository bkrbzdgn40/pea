import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

void main() {
  const factory = AnalysisEngineFactory();

  test('common AnalysisEngine remains the shared lifecycle surface', () {
    final engines = <AnalysisEngine>[
      factory.createRangeRep(
        config: _squatConfig(),
        rangeRepContract: RangeRepContracts.squat,
      ),
      factory.createHold(
        config: _plankConfig(),
        holdContract: HoldContracts.plankFamily,
      ),
    ];

    engines.first.update(AnalysisFrame(primaryMetric: 170.0, formMetric: 60.0));
    engines.last.update(
      AnalysisFrame(
        primaryMetric: 170.0,
        formMetric: 170.0,
        bodyLineAngle: 170.0,
        armSupportAngle: 90.0,
        legExtensionAngle: 170.0,
      ),
    );

    for (final engine in engines) {
      engine.interrupt(reason: 'paused');
      engine.reset();
    }
  });

  test('range-rep family boundary exposes typed rep semantics', () {
    final RangeRepAnalysisEngine engine = factory.createRangeRep(
      config: _squatConfig(),
      rangeRepContract: RangeRepContracts.squat,
    );

    expect(engine.repCount, 0);
    expect(engine.lastRepRom, 180.0);
    expect(engine.detectionDiagnosticsSnapshot.hasActiveRepPhase, isFalse);
    expect(engine.phaseLabel, rangeRepAwaitNeutralPhaseLabel);
  });

  test('hold family boundary exposes typed hold semantics', () {
    final HoldAnalysisEngine engine = factory.createHold(
      config: _plankConfig(),
      holdContract: HoldContracts.plankFamily,
    );

    final diagnostics = engine.diagnosticsSnapshot;

    expect(engine.feedbackCode, HoldFeedbackCode.preparePosition);
    expect(diagnostics.phase, HoldPhase.ready);
    expect(diagnostics.currentHoldSeconds, 0.0);
    expect(diagnostics.bestHoldSeconds, 0.0);
    expect(diagnostics.isHolding, isFalse);
  });
}

ExerciseConfig _squatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
  );
}

ExerciseConfig _plankConfig() {
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
