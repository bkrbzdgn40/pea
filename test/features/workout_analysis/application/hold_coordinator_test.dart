import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  group('DefaultHoldCoordinator', () {
    test('drives the real hold engine through a stable visible hold', () {
      final clock = _TestClock();
      final coordinator = _buildCoordinator(clock);

      _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);
      clock.advance(const Duration(seconds: 5));
      final holdingResult = _processAcceptedHoldFrame(
        coordinator,
        clock,
        side: HoldSide.left,
      );

      expect(holdingResult.stateSnapshot.selectedHoldSide, HoldSide.left);
      expect(
        holdingResult.stateSnapshot.currentHoldSeconds,
        closeTo(5.0, 0.001),
      );
      expect(holdingResult.stateSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(holdingResult.stateSnapshot.isHolding, isTrue);
      expect(
        holdingResult.stateSnapshot.holdFeedbackCode,
        HoldFeedbackCode.holdPosition,
      );
      expect(holdingResult.stateSnapshot.holdEnginePhase, HoldPhase.holding);
      expect(holdingResult.diagnosticsUpdate.recordAcceptedPoseFrame, isTrue);
    });

    test(
      'brief visibility suspension preserves the frozen side on recovery',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.right);
        clock.advance(const Duration(seconds: 5));
        _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.right);

        expect(coordinator.requiredHoldSideForAssessment(), HoldSide.right);

        final invalidResult = _processInvalidHoldFrame(coordinator, clock);

        expect(invalidResult.stateSnapshot.selectedHoldSide, HoldSide.right);
        expect(invalidResult.stateSnapshot.isHoldVisibilitySuspended, isTrue);
        expect(
          invalidResult.stateSnapshot.holdFeedbackCode,
          HoldFeedbackCode.bodyNotVisible,
        );
        expect(invalidResult.stateSnapshot.holdEnginePhase, HoldPhase.holding);
        expect(coordinator.requiredHoldSideForAssessment(), HoldSide.right);

        clock.advance(const Duration(seconds: 1));
        final resumedResult = _processAcceptedHoldFrame(
          coordinator,
          clock,
          side: HoldSide.right,
          didBecomeStableTracking: true,
        );

        expect(resumedResult.stateSnapshot.selectedHoldSide, HoldSide.right);
        expect(
          resumedResult.stateSnapshot.currentHoldSeconds,
          closeTo(5.0, 0.001),
        );
        expect(resumedResult.stateSnapshot.isHoldVisibilitySuspended, isFalse);
        expect(resumedResult.diagnosticsUpdate.recordPoseReacquisition, isTrue);

        clock.advance(const Duration(seconds: 1));
        final progressedResult = _processAcceptedHoldFrame(
          coordinator,
          clock,
          side: HoldSide.right,
        );

        expect(
          progressedResult.stateSnapshot.currentHoldSeconds,
          closeTo(6.0, 0.001),
        );
      },
    );

    test('long visibility gap ends the old hold and clears side ownership', () {
      final clock = _TestClock();
      final coordinator = _buildCoordinator(clock);

      _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);
      clock.advance(const Duration(seconds: 5));
      _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);

      _processInvalidHoldFrame(coordinator, clock);
      clock.advance(const Duration(milliseconds: 1200));

      final endedResult = _processAcceptedHoldFrame(
        coordinator,
        clock,
        side: HoldSide.left,
        didBecomeStableTracking: true,
      );

      expect(endedResult.stateSnapshot.selectedHoldSide, isNull);
      expect(endedResult.stateSnapshot.currentHoldSeconds, 0);
      expect(endedResult.stateSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(
        endedResult.stateSnapshot.holdFeedbackCode,
        HoldFeedbackCode.preparePosition,
      );
      expect(endedResult.stateSnapshot.holdEnginePhase, HoldPhase.ready);
      expect(coordinator.requiredHoldSideForAssessment(), isNull);
    });

    test(
      'lifecycle interruption ends the active hold and resets side state',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);
        clock.advance(const Duration(seconds: 5));
        _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);

        final interrupted = coordinator.handleLifecycleInterruption(
          reason: 'paused',
        );

        expect(interrupted.selectedHoldSide, isNull);
        expect(interrupted.currentHoldSeconds, 0);
        expect(interrupted.bestHoldSeconds, closeTo(5.0, 0.001));
        expect(interrupted.isHolding, isFalse);
        expect(interrupted.isHoldVisibilitySuspended, isFalse);
        expect(interrupted.holdFeedbackCode, HoldFeedbackCode.preparePosition);
        expect(interrupted.holdEnginePhase, HoldPhase.ready);
        expect(interrupted.currentPhase, 'READY');
        expect(coordinator.requiredHoldSideForAssessment(), isNull);

        _processAcceptedHoldFrame(coordinator, clock, side: HoldSide.left);
        clock.advance(const Duration(seconds: 1));
        final restarted = _processAcceptedHoldFrame(
          coordinator,
          clock,
          side: HoldSide.left,
        );

        expect(restarted.stateSnapshot.currentHoldSeconds, closeTo(1.0, 0.001));
        expect(restarted.stateSnapshot.bestHoldSeconds, closeTo(5.0, 0.001));
      },
    );
  });
}

DefaultHoldCoordinator _buildCoordinator(_TestClock clock) {
  final config = _plankConfig();
  final engine = const AnalysisEngineFactory().create(
    engineKind: EngineKind.hold,
    config: config,
    holdContract: HoldContracts.plankFamily,
    now: clock.now,
  );

  return DefaultHoldCoordinator(engine: engine, config: config);
}

HoldCoordinatorFrameResult _processAcceptedHoldFrame(
  DefaultHoldCoordinator coordinator,
  _TestClock clock, {
  required HoldSide side,
  bool didBecomeStableTracking = false,
}) {
  coordinator.selectHoldSideForAcceptedPose(_acceptedHoldAssessment(side));
  return coordinator.processFrame(
    metrics: _holdMetrics(side: side),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: didBecomeStableTracking,
  );
}

HoldCoordinatorFrameResult _processInvalidHoldFrame(
  DefaultHoldCoordinator coordinator,
  _TestClock clock,
) {
  return coordinator.processFrame(
    metrics: const ExerciseMetrics.noPose(),
    now: clock.now(),
    isAcceptedPoseFrame: false,
    didBecomeStableTracking: false,
  );
}

PoseQualityAssessment _acceptedHoldAssessment(HoldSide side) {
  return PoseQualityAssessment(
    isAccepted: true,
    minimumRequiredLikelihood: 0.66,
    meanRequiredLikelihood: 0.66,
    requiredLandmarkCount: 6,
    acceptedLandmarkCount: 6,
    acceptedHoldSides: <HoldSide>{side},
    preferredHoldSide: side,
    qualityScore: 1006.66,
  );
}

ExerciseMetrics _holdMetrics({
  required HoldSide side,
  double bodyLineAngle = 170.0,
  double armSupportAngle = 90.0,
  double legExtensionAngle = 170.0,
}) {
  return ExerciseMetrics(
    primaryAngle: bodyLineAngle,
    formMetric: bodyLineAngle,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: const <PoseLandmark>[],
    leftRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.left,
    ),
    rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.right,
    ),
    bodyLineAngle: bodyLineAngle,
    armSupportAngle: armSupportAngle,
    legExtensionAngle: legExtensionAngle,
    holdSide: side,
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

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
