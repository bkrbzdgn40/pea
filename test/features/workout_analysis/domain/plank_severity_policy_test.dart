import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_posture_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_posture_severity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

void main() {
  final policy = HoldPosturePolicy(config: _config().resolvedHoldPosture);

  group('plank severity policy', () {
    test(
      'leg extension failure is warning-level and does not invalidate hold',
      () {
        final evaluation = policy.evaluate(
          _signals(alignment: 170, support: 90, extension: 164),
          isHolding: true,
        );

        expect(evaluation.isValidHoldPosture, isTrue);
        expect(evaluation.supportsGraceWindow, isFalse);
        expect(
          evaluation.postureDiagnostics.severity,
          HoldPostureSeverity.warning,
        );
        expect(evaluation.postureDiagnostics.areLegsExtended, isFalse);
        expect(evaluation.correctiveFeedbackCode, HoldFeedbackCode.extendLegs);
      },
    );

    test('alignment failure remains critical and grace-eligible', () {
      final evaluation = policy.evaluate(
        _signals(alignment: 165, support: 90, extension: 170),
        isHolding: true,
      );

      expect(evaluation.isValidHoldPosture, isFalse);
      expect(evaluation.supportsGraceWindow, isTrue);
      expect(
        evaluation.postureDiagnostics.severity,
        HoldPostureSeverity.critical,
      );
      expect(evaluation.correctiveFeedbackCode, HoldFeedbackCode.alignHips);
    });

    test('support failure remains critical and bypasses grace', () {
      final evaluation = policy.evaluate(
        _signals(alignment: 170, support: 59, extension: 170),
        isHolding: true,
      );

      expect(evaluation.isValidHoldPosture, isFalse);
      expect(evaluation.supportsGraceWindow, isFalse);
      expect(
        evaluation.postureDiagnostics.severity,
        HoldPostureSeverity.critical,
      );
      expect(
        evaluation.correctiveFeedbackCode,
        HoldFeedbackCode.adjustElbowSupport,
      );
    });
  });

  test('warning-level leg extension feedback keeps the engine holding', () {
    final engine = HoldEngine(posturePolicy: policy);

    engine.update(_frame(alignment: 170, support: 90, extension: 170));
    engine.update(_frame(alignment: 170, support: 90, extension: 164));

    expect(engine.diagnosticsSnapshot.phase, HoldPhase.holding);
    expect(engine.diagnosticsSnapshot.isHolding, isTrue);
    expect(engine.diagnosticsSnapshot.hadFormBreak, isFalse);
    expect(
      engine.diagnosticsSnapshot.postureSeverity,
      HoldPostureSeverity.warning,
    );
    expect(engine.feedbackCode, HoldFeedbackCode.extendLegs);
  });
}

ExerciseConfig _config() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
  );
}

HoldSignalValues _signals({
  required double alignment,
  required double support,
  required double extension,
}) {
  return HoldSignalValues.legacy(
    alignment: alignment,
    support: support,
    extension: extension,
  );
}

AnalysisFrame _frame({
  required double alignment,
  required double support,
  required double extension,
}) {
  return AnalysisFrame(
    primaryMetric: alignment,
    formMetric: alignment,
    bodyLineAngle: alignment,
    armSupportAngle: support,
    legExtensionAngle: extension,
  );
}
