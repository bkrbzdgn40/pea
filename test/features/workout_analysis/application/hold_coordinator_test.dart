import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
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

    test('publishes hold-only state and hold-only calibration metrics', () {
      final clock = _TestClock();
      final coordinator = _buildCoordinator(clock);

      final firstResult = _processAcceptedHoldFrame(
        coordinator,
        clock,
        side: HoldSide.left,
      );

      expect(
        firstResult.stateSnapshot.calibrationMetrics.analysisKind.name,
        'hold',
      );
      expect(firstResult.stateSnapshot.calibrationMetrics.rangeRep, isNull);
      expect(
        firstResult.stateSnapshot.calibrationMetrics.currentBodyLineAngle,
        closeTo(170.0, 0.001),
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.currentArmSupportAngle,
        closeTo(90.0, 0.001),
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.currentLegExtensionAngle,
        closeTo(170.0, 0.001),
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.currentHoldSignalValues
            .asMap(),
        <HoldSignal, double>{
          HoldSignal.alignment: 170.0,
          HoldSignal.support: 90.0,
          HoldSignal.extension: 170.0,
        },
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.targetHoldSignalValues
            .asMap(),
        <HoldSignal, double>{HoldSignal.alignment: 166.0},
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.holdSignalValidity.asMap(),
        <HoldSignal, bool>{
          HoldSignal.alignment: true,
          HoldSignal.support: true,
          HoldSignal.extension: true,
        },
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
        isNull,
      );
      expect(
        firstResult.stateSnapshot.calibrationMetrics.hasLastRangeRepValidation,
        isFalse,
      );

      final dynamic dynamicSnapshot = firstResult.stateSnapshot;
      expect(() => dynamicSnapshot.repCount, throwsNoSuchMethodError);
      expect(() => dynamicSnapshot.lastRepScore, throwsNoSuchMethodError);
      expect(() => dynamicSnapshot.lastRepRom, throwsNoSuchMethodError);
    });

    test(
      'side plank requires the support elbow to stack under the shoulder',
      () {
        final clock = _TestClock();
        final config = _plankConfig();
        final engine = const AnalysisEngineFactory().createHold(
          config: config,
          holdContract: HoldContracts.sidePlank,
          now: clock.now,
        );
        final coordinator = DefaultHoldCoordinator(
          engine: engine,
          config: config,
          holdContract: HoldContracts.sidePlank,
        );

        coordinator.selectHoldSideForAcceptedPose(
          _acceptedHoldAssessment(HoldSide.left),
        );
        final stacked = coordinator.processFrame(
          metrics: _sidePlankMetrics(
            shoulderX: 0,
            shoulderY: 0,
            elbowX: 0,
            elbowY: 2,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
        );

        expect(stacked.stateSnapshot.isHolding, isTrue);
        expect(
          stacked.stateSnapshot.calibrationMetrics.currentHoldSignalValues
              .valueFor(HoldSignal.supportStacking),
          closeTo(1, 0.001),
        );

        final badEngine = const AnalysisEngineFactory().createHold(
          config: config,
          holdContract: HoldContracts.sidePlank,
          now: clock.now,
        );
        final badCoordinator = DefaultHoldCoordinator(
          engine: badEngine,
          config: config,
          holdContract: HoldContracts.sidePlank,
        );
        badCoordinator.selectHoldSideForAcceptedPose(
          _acceptedHoldAssessment(HoldSide.left),
        );
        final unstacked = badCoordinator.processFrame(
          metrics: _sidePlankMetrics(
            shoulderX: 0,
            shoulderY: 2,
            elbowX: 0,
            elbowY: 0,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
        );

        expect(unstacked.stateSnapshot.isHolding, isFalse);
        expect(unstacked.stateSnapshot.holdEnginePhase, HoldPhase.broken);
        expect(
          unstacked.stateSnapshot.holdFeedbackCode,
          HoldFeedbackCode.placeSupportElbowUnderShoulder,
        );
        expect(
          unstacked.stateSnapshot.calibrationMetrics.holdSignalValidity
              .validityFor(HoldSignal.supportStacking),
          isFalse,
        );
      },
    );

    test('side plank accepts stacked straight-arm hand support', () {
      final clock = _TestClock();
      final config = _plankConfig();
      final engine = const AnalysisEngineFactory().createHold(
        config: config,
        holdContract: HoldContracts.sidePlank,
        now: clock.now,
      );
      final coordinator = DefaultHoldCoordinator(
        engine: engine,
        config: config,
        holdContract: HoldContracts.sidePlank,
      );

      coordinator.selectHoldSideForAcceptedPose(
        _acceptedHoldAssessment(HoldSide.left),
      );
      final result = coordinator.processFrame(
        metrics: _sidePlankMetrics(
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 0,
          elbowY: 2,
          armSupportAngle: 170,
        ),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: false,
      );

      expect(result.stateSnapshot.isHolding, isTrue);
      expect(
        result.stateSnapshot.calibrationMetrics.holdSignalValidity.validityFor(
          HoldSignal.support,
        ),
        isTrue,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.holdSignalValidity.validityFor(
          HoldSignal.supportStacking,
        ),
        isTrue,
      );
    });

    test('side plank does not start until the hips clear the floor line', () {
      final clock = _TestClock();
      final config = _plankConfig();
      final engine = const AnalysisEngineFactory().createHold(
        config: config,
        holdContract: HoldContracts.sidePlank,
        now: clock.now,
      );
      final coordinator = DefaultHoldCoordinator(
        engine: engine,
        config: config,
        holdContract: HoldContracts.sidePlank,
      );

      coordinator.selectHoldSideForAcceptedPose(
        _acceptedHoldAssessment(HoldSide.left),
      );
      final collapsed = coordinator.processFrame(
        metrics: _sidePlankMetrics(
          shoulderX: 0,
          shoulderY: 0,
          elbowX: 0,
          elbowY: 2,
          hipX: 5,
          hipY: 2,
          ankleX: 10,
          ankleY: 2,
        ),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: false,
      );

      expect(collapsed.stateSnapshot.isHolding, isFalse);
      expect(collapsed.stateSnapshot.currentHoldSeconds, 0);
      expect(collapsed.stateSnapshot.holdEnginePhase, HoldPhase.broken);
      expect(
        collapsed.stateSnapshot.holdFeedbackCode,
        HoldFeedbackCode.liftHips,
      );
      expect(
        collapsed.stateSnapshot.calibrationMetrics.holdSignalValidity
            .validityFor(HoldSignal.hipClearance),
        isFalse,
      );
    });

    test('reads invalid-frame target signals from engine diagnostics', () {
      final coordinator = DefaultHoldCoordinator(
        engine: _FakeHoldAnalysisEngine(
          diagnostics: HoldDiagnosticsSnapshot(
            targetSignalValues: HoldSignalValues(
              values: <HoldSignal, double>{HoldSignal.support: 42.0},
            ),
            feedbackCode: HoldFeedbackCode.preparePosition,
            phase: HoldPhase.ready,
          ),
        ),
        config: _plankConfig(),
        holdContract: HoldContracts.plankFamily,
      );

      final result = coordinator.processFrame(
        metrics: const ExerciseMetrics.noPose(),
        now: DateTime(2026, 1, 1, 12),
        isAcceptedPoseFrame: false,
        didBecomeStableTracking: false,
      );

      expect(
        result.stateSnapshot.calibrationMetrics.targetHoldSignalValues.valueFor(
          HoldSignal.support,
        ),
        42.0,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.targetHoldSignalValues.valueFor(
          HoldSignal.alignment,
        ),
        isNull,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.currentHoldSignalValues.signals,
        isEmpty,
      );
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
          invalidResult.diagnosticsUpdate.recordHoldVisibilitySuspend,
          isTrue,
        );
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
        expect(
          resumedResult.diagnosticsUpdate.recordHoldVisibilityRecovery,
          isTrue,
        );
        expect(
          resumedResult.diagnosticsUpdate.holdVisibilityGapDuration,
          const Duration(seconds: 1),
        );

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

      final invalidResult = _processInvalidHoldFrame(coordinator, clock);
      expect(
        invalidResult.diagnosticsUpdate.recordHoldVisibilitySuspend,
        isTrue,
      );
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
      expect(endedResult.diagnosticsUpdate.recordHoldVisibilityAbort, isTrue);
      expect(
        endedResult.diagnosticsUpdate.holdVisibilityGapDuration,
        const Duration(milliseconds: 1200),
      );
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
  final engine = const AnalysisEngineFactory().createHold(
    config: config,
    holdContract: HoldContracts.plankFamily,
    now: clock.now,
  );

  return DefaultHoldCoordinator(
    engine: engine,
    config: config,
    holdContract: HoldContracts.plankFamily,
  );
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

ExerciseMetrics _sidePlankMetrics({
  required double shoulderX,
  required double shoulderY,
  required double elbowX,
  required double elbowY,
  double? wristX,
  double? wristY,
  double hipX = 5,
  double hipY = 0,
  double ankleX = 10,
  double ankleY = 2,
  double armSupportAngle = 90,
}) {
  return ExerciseMetrics(
    primaryAngle: 170,
    formMetric: 170,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: <PoseLandmark>[
      PoseLandmark(
        type: PoseLandmarkType.leftShoulder,
        x: shoulderX,
        y: shoulderY,
        z: 0,
        likelihood: 0.99,
      ),
      PoseLandmark(
        type: PoseLandmarkType.leftElbow,
        x: elbowX,
        y: elbowY,
        z: 0,
        likelihood: 0.99,
      ),
      PoseLandmark(
        type: PoseLandmarkType.leftWrist,
        x: wristX ?? elbowX,
        y: wristY ?? (elbowY + 1),
        z: 0,
        likelihood: 0.99,
      ),
      PoseLandmark(
        type: PoseLandmarkType.leftHip,
        x: hipX,
        y: hipY,
        z: 0,
        likelihood: 0.99,
      ),
      PoseLandmark(
        type: PoseLandmarkType.leftAnkle,
        x: ankleX,
        y: ankleY,
        z: 0,
        likelihood: 0.99,
      ),
    ],
    leftRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.left,
    ),
    rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.right,
    ),
    holdSignalValues: HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.alignment: 170,
        HoldSignal.support: armSupportAngle,
        HoldSignal.extension: 170,
      },
    ),
    holdSide: HoldSide.left,
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

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

class _FakeHoldAnalysisEngine implements HoldAnalysisEngine {
  _FakeHoldAnalysisEngine({required this.diagnostics});

  HoldDiagnosticsSnapshot diagnostics;

  @override
  HoldDiagnosticsSnapshot get diagnosticsSnapshot => diagnostics;

  @override
  HoldFeedbackCode get feedbackCode => diagnostics.feedbackCode;

  @override
  void beginVisibilityGap() {}

  @override
  void interrupt({String? reason}) {}

  @override
  void reset() {}

  @override
  HoldVisibilityResumeResult resumeAfterVisibilityGap() {
    return const HoldVisibilityResumeResult(
      disposition: HoldVisibilityResumeDisposition.noGap,
    );
  }

  @override
  void update(AnalysisFrame frame) {
    diagnostics = HoldDiagnosticsSnapshot(
      currentHoldSeconds: diagnostics.currentHoldSeconds,
      bestHoldSeconds: diagnostics.bestHoldSeconds,
      isHolding: diagnostics.isHolding,
      isVisibilitySuspended: diagnostics.isVisibilitySuspended,
      hadFormBreak: diagnostics.hadFormBreak,
      phase: diagnostics.phase,
      feedbackCode: diagnostics.feedbackCode,
      targetSignalValues: diagnostics.targetSignalValues,
      lastVisiblePosture: HoldPostureDiagnosticsSnapshot(
        hasCompleteMetrics: true,
        hasActivePosture: true,
        signalValidity: HoldSignalValidity(
          values: <HoldSignal, bool>{
            for (final signal in frame.holdSignalValues.signals) signal: true,
          },
        ),
      ),
    );
  }
}
