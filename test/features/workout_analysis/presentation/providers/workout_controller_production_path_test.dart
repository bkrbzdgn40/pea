import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  group('WorkoutController production pose pipeline', () {
    late _QueuedPoseDetector detector;
    late _FakeClock clock;
    late ProviderContainer container;
    late WorkoutController controller;
    late ProviderSubscription<WorkoutState> subscription;

    setUp(() {
      detector = _QueuedPoseDetector();
      clock = _FakeClock();
      container = ProviderContainer(
        overrides: <Override>[
          activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
          exerciseConfigProvider.overrideWith((ref) => _squatConfig()),
          poseDetectorProvider.overrideWith((ref) => detector),
          workoutClockProvider.overrideWithValue(clock.now),
        ],
      );
      addTearDown(container.dispose);
      subscription = container.listen<WorkoutState>(
        workoutControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      controller = container.read(workoutControllerProvider.notifier);
    });

    test(
      'rejected poses do not reach the engine and diagnostics stay in schema '
      'v3',
      () async {
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 170, defaultLikelihood: 0.40),
        ]);
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 170, defaultLikelihood: 0.40),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 0);
        expect(snapshot.schemaVersion, 3);
        expect(snapshot.acceptedPoseFrameCount, 0);
        expect(snapshot.rejectedPoseFrameCount, 2);
        expect(snapshot.lowConfidencePoseFrameCount, 2);
        expect(snapshot.lastPoseRejectionReason, 'low_landmark_likelihood');
        expect(snapshot.toJson()['schema_version'], 3);
      },
    );

    test(
      'accepted candidate wins over a higher-scoring rejected candidate',
      () async {
        final acceptedPose = _squatPose(angle: 170, defaultLikelihood: 0.66);
        final rejectedPose = _squatPose(
          angle: 90,
          defaultLikelihood: 1.0,
          likelihoodOverrides: const <PoseLandmarkType, double>{
            PoseLandmarkType.leftAnkle: 0.49,
          },
        );

        await _analyzeFrame(controller, detector, <Pose>[
          acceptedPose,
          rejectedPose,
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          acceptedPose,
          rejectedPose,
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(snapshot.detectedPoseFrameCount, 2);
        expect(snapshot.rejectedPoseFrameCount, 0);
        expect(snapshot.acceptedPoseFrameCount, 1);
        expect(snapshot.currentPoseQualityStatus, 'accepted');
        expect(state.currentAngle, closeTo(170.0, 0.001));
      },
    );

    test(
      'accepted candidate still wins when the rejected pose appears first',
      () async {
        final acceptedPose = _squatPose(angle: 170, defaultLikelihood: 0.66);
        final rejectedPose = _squatPose(
          angle: 90,
          defaultLikelihood: 1.0,
          likelihoodOverrides: const <PoseLandmarkType, double>{
            PoseLandmarkType.leftAnkle: 0.49,
          },
        );

        await _analyzeFrame(controller, detector, <Pose>[
          rejectedPose,
          acceptedPose,
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          rejectedPose,
          acceptedPose,
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(snapshot.detectedPoseFrameCount, 2);
        expect(snapshot.rejectedPoseFrameCount, 0);
        expect(snapshot.acceptedPoseFrameCount, 1);
        expect(snapshot.currentPoseQualityStatus, 'accepted');
        expect(state.currentAngle, closeTo(170.0, 0.001));
      },
    );

    test(
      'all-rejected multi-pose frame uses the best rejected reason once',
      () async {
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(
            angle: 90,
            defaultLikelihood: 1.0,
            likelihoodOverrides: const <PoseLandmarkType, double>{
              PoseLandmarkType.leftAnkle: 0.49,
            },
          ),
          _squatPose(
            angle: 170,
            defaultLikelihood: 0.95,
            missingLandmarks: const <PoseLandmarkType>{
              PoseLandmarkType.leftAnkle,
            },
          ),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(snapshot.detectedPoseFrameCount, 1);
        expect(snapshot.acceptedPoseFrameCount, 0);
        expect(snapshot.rejectedPoseFrameCount, 1);
        expect(snapshot.lastPoseRejectionReason, 'low_landmark_likelihood');
        expect(state.currentPhase, 'WAITING');
      },
    );

    test('one hallucinated accepted frame does not recover tracking', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, const <Pose>[]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');
      expect(snapshot.briefOcclusionRecoveryCount, 0);
      expect(snapshot.currentVisibilityStatus, 'brief_freeze');
    });

    test(
      'brief PEAK occlusion recovers and preserves the visible rep',
      () async {
        await _armAndReachPeak(controller, detector, clock);

        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 1000));
        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        await _driveUntilPhase(
          controller,
          detector,
          clock,
          _squatPose(angle: 110),
          expectedPhase: 'ASCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          controller,
          detector,
          clock,
          _squatPose(angle: 170),
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 1);
        expect(snapshot.resyncCount, 0);
        expect(snapshot.briefOcclusionRecoveryCount, 1);
        expect(snapshot.briefOcclusionAbortCount, 0);
      },
    );

    test('phase-incompatible brief recovery aborts the half rep', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 1000));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
      expect(snapshot.briefOcclusionAbortCount, 1);
      expect(snapshot.briefOcclusionRecoveryCount, 0);
      expect(snapshot.resyncCount, 1);
    });

    test(
      'temporal stabilization crossing the 1500 ms boundary hard-resyncs',
      () async {
        await _armAndReachPeak(controller, detector, clock);

        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 1490));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 0);
        expect(state.currentPhase, 'AWAITING_NEUTRAL');
        expect(snapshot.resyncCount, 1);
        expect(snapshot.briefOcclusionRecoveryCount, 0);
        expect(snapshot.briefOcclusionAbortCount, 0);
      },
    );

    test(
      'temporal stabilization completing below the boundary still recovers',
      () async {
        await _armAndReachPeak(controller, detector, clock);

        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 1200));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.currentPhase, 'PEAK');
        expect(snapshot.resyncCount, 0);
        expect(snapshot.briefOcclusionRecoveryCount, 1);
        expect(snapshot.briefOcclusionAbortCount, 0);
      },
    );

    test('long occlusion triggers a hard resync exactly once', () async {
      await _armAndReachPeak(controller, detector, clock);

      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 1500));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 90)]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_squatPose(angle: 170)]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
      expect(snapshot.resyncCount, 1);
      expect(snapshot.briefOcclusionRecoveryCount, 0);
      expect(snapshot.briefOcclusionAbortCount, 0);
    });

    test(
      'timeouted peak recovery does not update the old rep context',
      () async {
        await _armAndReachPeak(controller, detector, clock);

        await _analyzeFrame(controller, detector, const <Pose>[]);
        clock.advance(const Duration(milliseconds: 2000));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _squatPose(angle: 90),
        ]);
        await _driveUntilPhase(
          controller,
          detector,
          clock,
          _squatPose(angle: 170),
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 0);
        expect(state.currentPhase, 'NEUTRAL');
        expect(snapshot.resyncCount, 1);
        expect(snapshot.briefOcclusionRecoveryCount, 0);
        expect(snapshot.briefOcclusionAbortCount, 0);
      },
    );

    test('range-rep uses the only quality-accepted right side when left is '
        'rejected', () async {
      final pose = _bilateralSquatPose(
        leftAngle: 170,
        rightAngle: 95,
        leftDefaultLikelihood: 0.40,
        rightDefaultLikelihood: 0.95,
      );

      await _analyzeFrame(controller, detector, <Pose>[pose]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[pose]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.calibrationMetrics.selectedRangeRepSide, 'right');
      expect(snapshot.currentSelectedSide, 'right');
      expect(state.currentAngle, closeTo(95.0, 0.001));
    });

    test('range-rep uses the only quality-accepted left side when right is '
        'rejected', () async {
      final pose = _bilateralSquatPose(
        leftAngle: 105,
        rightAngle: 170,
        leftDefaultLikelihood: 0.95,
        rightDefaultLikelihood: 0.40,
      );

      await _analyzeFrame(controller, detector, <Pose>[pose]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[pose]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.calibrationMetrics.selectedRangeRepSide, 'left');
      expect(snapshot.currentSelectedSide, 'left');
      expect(state.currentAngle, closeTo(105.0, 0.001));
    });

    test(
      'both quality-accepted sides keep the previous side behavior',
      () async {
        await _pumpAcceptedPose(
          controller,
          detector,
          clock,
          _leftOnlyAcceptedSquatPose(angle: 170),
          count: 2,
          spacing: const Duration(milliseconds: 100),
        );
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _bothAcceptedSquatPose(leftAngle: 150, rightAngle: 95),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.calibrationMetrics.selectedRangeRepSide, 'left');
        expect(snapshot.currentSelectedSide, 'left');
      },
    );

    test('active left rep does not switch to right when only right remains '
        'quality-accepted', () async {
      await _establishActiveLeftRepContext(controller, detector, clock);

      await _analyzeFrame(controller, detector, <Pose>[
        _rightOnlyAcceptedSquatPose(leftAngle: 140, rightAngle: 95),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');
      expect(state.calibrationMetrics.selectedRangeRepSide, 'left');
      expect(snapshot.currentSelectedSide, 'left');
      expect(snapshot.activeRepSideSwitchCount, 0);
      expect(snapshot.currentVisibilityStatus, 'brief_freeze');
    });

    test(
      'frozen left side recovers when left becomes quality-accepted again',
      () async {
        await _establishActiveLeftRepContext(controller, detector, clock);

        await _analyzeFrame(controller, detector, <Pose>[
          _rightOnlyAcceptedSquatPose(leftAngle: 140, rightAngle: 95),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _leftOnlyAcceptedSquatPose(angle: 140),
        ]);
        clock.advance(const Duration(milliseconds: 100));
        await _analyzeFrame(controller, detector, <Pose>[
          _leftOnlyAcceptedSquatPose(angle: 140),
        ]);

        final state = container.read(workoutControllerProvider);
        final snapshot = controller.diagnosticsSnapshot();

        expect(state.repCount, 0);
        expect(state.calibrationMetrics.selectedRangeRepSide, 'left');
        expect(snapshot.currentSelectedSide, 'left');
        expect(snapshot.activeRepSideSwitchCount, 0);
        expect(snapshot.briefOcclusionRecoveryCount, 1);
      },
    );

    test('frozen left side does not recover or switch when only right is '
        'quality-accepted', () async {
      await _establishActiveLeftRepContext(controller, detector, clock);

      await _analyzeFrame(controller, detector, <Pose>[
        _rightOnlyAcceptedSquatPose(leftAngle: 140, rightAngle: 95),
      ]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[
        _rightOnlyAcceptedSquatPose(leftAngle: 140, rightAngle: 95),
      ]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[
        _rightOnlyAcceptedSquatPose(leftAngle: 140, rightAngle: 95),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');
      expect(state.calibrationMetrics.selectedRangeRepSide, 'left');
      expect(snapshot.currentSelectedSide, 'left');
      expect(snapshot.activeRepSideSwitchCount, 0);
      expect(snapshot.briefOcclusionRecoveryCount, 0);
      expect(snapshot.currentVisibilityStatus, 'brief_freeze');
    });
  });

  test(
    'hold rejects low-confidence poses and does not start a false hold',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(defaultLikelihood: 0.40),
      ]);
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(defaultLikelihood: 0.40),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.isHolding, isFalse);
      expect(state.currentHoldSeconds, 0);
      expect(state.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Vucut net gorunmuyor.');
      expect(state.currentPhase, 'WAITING');
      expect(snapshot.acceptedPoseFrameCount, 0);
      expect(snapshot.rejectedPoseFrameCount, 2);
    },
  );

  test('hold missing required landmark does not start a false hold', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _analyzeFrame(controller, detector, <Pose>[
      _plankPose(
        missingLandmarks: const <PoseLandmarkType>{PoseLandmarkType.leftKnee},
      ),
    ]);
    clock.advance(const Duration(milliseconds: 100));
    await _analyzeFrame(controller, detector, <Pose>[
      _plankPose(
        missingLandmarks: const <PoseLandmarkType>{PoseLandmarkType.leftKnee},
      ),
    ]);

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();

    expect(state.isHolding, isFalse);
    expect(state.currentHoldSeconds, 0);
    expect(state.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
    expect(state.holdEnginePhase, HoldPhase.ready);
    expect(state.feedbackMessage, 'Vucut net gorunmuyor.');
    expect(state.currentPhase, 'WAITING');
    expect(snapshot.acceptedPoseFrameCount, 0);
    expect(snapshot.rejectedPoseFrameCount, 2);
    expect(snapshot.lastPoseRejectionReason, 'missing_required_landmark');
  });

  test(
    'valid left hold exposes typed feedback, phase, and UI message',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock);

      final state = container.read(workoutControllerProvider);

      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.isHolding, isTrue);
      expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Pozisyonu Koru');
      expect(state.currentPhase, 'HOLDING');
    },
  );

  test(
    'right-only controller pipeline starts a hold on the right side',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);
      clock.advance(const Duration(seconds: 5));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.isHolding, isTrue);
      expect(state.selectedHoldSide, HoldSide.right);
      expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Pozisyonu Koru');
      expect(state.currentPhase, 'HOLDING');
      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(snapshot.acceptedPoseFrameCount, 2);
    },
  );

  test('hold body failure exposes typed broken-state feedback', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftBodyLineAngle: 162,
      ),
    ]);
    clock.advance(const Duration(milliseconds: 100));
    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftBodyLineAngle: 162,
      ),
    ]);

    final state = container.read(workoutControllerProvider);
    expect(state.isHolding, isFalse);
    expect(state.holdFeedbackCode, HoldFeedbackCode.alignHips);
    expect(state.holdEnginePhase, HoldPhase.broken);
    expect(state.feedbackMessage, 'Kalcayi Hizala');
    expect(state.currentPhase, 'BROKEN');
  });

  test('hold arm failure exposes typed broken-state feedback', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftArmSupportAngle: 0,
      ),
    ]);
    clock.advance(const Duration(milliseconds: 100));
    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftArmSupportAngle: 0,
      ),
    ]);

    final state = container.read(workoutControllerProvider);
    expect(state.isHolding, isFalse);
    expect(state.holdFeedbackCode, HoldFeedbackCode.adjustElbowSupport);
    expect(state.holdEnginePhase, HoldPhase.broken);
    expect(state.feedbackMessage, 'Dirsek Destegini Duzelt');
    expect(state.currentPhase, 'BROKEN');
  });

  test('hold leg failure exposes typed broken-state feedback', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftLegExtensionAngle: 120,
      ),
    ]);
    clock.advance(const Duration(milliseconds: 100));
    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(
        leftLikelihood: 0.99,
        rightLikelihood: 0.40,
        leftLegExtensionAngle: 120,
      ),
    ]);

    final state = container.read(workoutControllerProvider);
    expect(state.isHolding, isFalse);
    expect(state.holdFeedbackCode, HoldFeedbackCode.extendLegs);
    expect(state.holdEnginePhase, HoldPhase.broken);
    expect(state.feedbackMessage, 'Dizleri Kaldir');
    expect(state.currentPhase, 'BROKEN');
  });

  test(
    'confirmed side switch resets hold metric smoothing before the new side is processed',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;
      final leftPreferredPose = _bilateralPlankPose(
        leftLikelihood: 0.96,
        rightLikelihood: 0.40,
        leftBodyLineAngle: 180,
        leftArmSupportAngle: 150,
        rightBodyLineAngle: 165,
        rightArmSupportAngle: 60,
      );
      final rightPreferredPose = _bilateralPlankPose(
        leftLikelihood: 0.72,
        rightLikelihood: 0.96,
        leftBodyLineAngle: 180,
        leftArmSupportAngle: 150,
        rightBodyLineAngle: 165,
        rightArmSupportAngle: 60,
      );

      await _analyzeFrame(controller, detector, <Pose>[leftPreferredPose]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[leftPreferredPose]);

      var state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.isHolding, isFalse);

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[rightPreferredPose]);

      state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.isHolding, isFalse);

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[rightPreferredPose]);

      state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.right);
      expect(state.isHolding, isFalse);
      expect(state.currentHoldSeconds, 0);
      expect(state.holdFeedbackCode, HoldFeedbackCode.alignHips);
      expect(state.holdEnginePhase, HoldPhase.broken);
    },
  );

  test(
    'active hold keeps the locked right side when the left side appears alone',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock, rightOnly: true);

      var state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.right);
      expect(state.isHolding, isTrue);

      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.right);
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isTrue);
      expect(state.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Vucut net gorunmuyor.');
      expect(state.currentPhase, 'WAITING');

      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);
      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);

      state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.right);
      expect(state.isHolding, isTrue);
    },
  );

  test('active hold ignores a higher-quality alternate side', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _establishVisibleHold(controller, detector, clock, rightOnly: true);

    clock.advance(const Duration(seconds: 1));
    await _analyzeFrame(controller, detector, <Pose>[
      _bilateralPlankPose(leftLikelihood: 0.99, rightLikelihood: 0.70),
    ]);

    final state = container.read(workoutControllerProvider);
    expect(state.selectedHoldSide, HoldSide.right);
    expect(state.isHolding, isTrue);
    expect(state.currentHoldSeconds, closeTo(6.0, 0.001));
    expect(state.isHoldVisibilitySuspended, isFalse);
    expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(state.holdEnginePhase, HoldPhase.holding);
    expect(state.feedbackMessage, 'Pozisyonu Koru');
  });

  test(
    'next hold attempt can switch to the left side after a right-side attempt ends',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock, rightOnly: true);

      clock.advance(const Duration(milliseconds: 200));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 500));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);
      clock.advance(const Duration(milliseconds: 500));
      await _analyzeFrame(controller, detector, <Pose>[
        _plankPose(rightOnly: true),
      ]);

      var state = container.read(workoutControllerProvider);
      expect(state.isHolding, isFalse);
      expect(state.selectedHoldSide, isNull);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      state = container.read(workoutControllerProvider);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.isHolding, isTrue);
    },
  );

  test('hold short visibility gap excludes hidden hold time', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _establishVisibleHold(controller, detector, clock);

    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, const <Pose>[]);
    var state = container.read(workoutControllerProvider);
    expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
    expect(state.isHolding, isFalse);
    expect(state.isHoldVisibilitySuspended, isTrue);
    expect(state.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
    expect(state.holdEnginePhase, HoldPhase.holding);
    expect(state.feedbackMessage, 'Vucut net gorunmuyor.');
    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
    clock.advance(const Duration(seconds: 1));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

    state = container.read(workoutControllerProvider);

    expect(state.isHolding, isTrue);
    expect(state.isHoldVisibilitySuspended, isFalse);
    expect(state.currentHoldSeconds, closeTo(6.0, 0.001));
    expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(state.holdEnginePhase, HoldPhase.holding);
  });

  test(
    'hold long visibility gap ends the old hold and restarts from zero',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock);

      clock.advance(const Duration(milliseconds: 200));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 500));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      clock.advance(const Duration(milliseconds: 500));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      var state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.hadHoldFormBreak, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Pozisyonu Hazirla');
      expect(state.currentPhase, 'READY');

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      state = container.read(workoutControllerProvider);
      expect(state.isHolding, isTrue);
      expect(state.currentHoldSeconds, 0);

      clock.advance(const Duration(seconds: 1));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.hadHoldFormBreak, isFalse);
    },
  );

  test('hold rejected pose behaves like visibility loss', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
    );
    addTearDown(harness.dispose);
    final container = harness.container;
    final controller = harness.controller;

    await _establishVisibleHold(controller, detector, clock);

    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, <Pose>[
      _plankPose(defaultLikelihood: 0.40),
    ]);
    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
    clock.advance(const Duration(milliseconds: 50));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
    clock.advance(const Duration(seconds: 1));
    await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

    final state = container.read(workoutControllerProvider);
    final snapshot = controller.diagnosticsSnapshot();

    expect(state.isHolding, isTrue);
    expect(state.currentHoldSeconds, closeTo(6.0, 0.001));
    expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(state.holdEnginePhase, HoldPhase.holding);
    expect(snapshot.rejectedPoseFrameCount, 1);
  });

  test(
    'hold one accepted reacquisition frame does not resume the old timer',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock);

      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, const <Pose>[]);
      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);

      final state = container.read(workoutControllerProvider);

      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isTrue);
      expect(state.holdFeedbackCode, HoldFeedbackCode.bodyNotVisible);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Vucut net gorunmuyor.');
      expect(state.currentPhase, 'WAITING');
    },
  );

  test(
    'hold lifecycle interruption ends the active hold and restarts from zero',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock);

      controller.handleLifecycleInterruption(reason: 'paused');

      var state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Pozisyonu Hazirla');
      expect(state.currentPhase, 'READY');
      expect(state.hadHoldFormBreak, isFalse);

      clock.advance(const Duration(seconds: 10));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      state = container.read(workoutControllerProvider);
      expect(state.isHolding, isFalse);
      expect(state.currentHoldSeconds, 0);

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      state = container.read(workoutControllerProvider);
      expect(state.isHolding, isTrue);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));

      clock.advance(const Duration(seconds: 1));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.hadHoldFormBreak, isFalse);
    },
  );

  test(
    'hold lifecycle interruption during READY preserves the idle state',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      controller.handleLifecycleInterruption(reason: 'paused');

      final state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, 0);
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Pozisyonu Hazirla');
      expect(state.currentPhase, 'READY');
      expect(state.hadHoldFormBreak, isFalse);
    },
  );

  test(
    'hold lifecycle interruption during visibility suspension clears the old '
    'hold',
    () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      final harness = _createHarness(
        exerciseType: ExerciseType.plank,
        config: _plankConfig(),
        detector: detector,
        clock: clock,
      );
      addTearDown(harness.dispose);
      final container = harness.container;
      final controller = harness.controller;

      await _establishVisibleHold(controller, detector, clock);

      clock.advance(const Duration(milliseconds: 50));
      await _analyzeFrame(controller, detector, const <Pose>[]);

      var state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHoldVisibilitySuspended, isTrue);

      controller.handleLifecycleInterruption(reason: 'paused');

      state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, 0);
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isFalse);
      expect(state.isHoldVisibilitySuspended, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Pozisyonu Hazirla');
      expect(state.currentPhase, 'READY');

      clock.advance(const Duration(seconds: 10));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      state = container.read(workoutControllerProvider);
      expect(state.isHolding, isTrue);
      expect(state.currentHoldSeconds, 0);

      clock.advance(const Duration(seconds: 1));
      await _analyzeFrame(controller, detector, <Pose>[_plankPose()]);
      state = container.read(workoutControllerProvider);
      expect(state.currentHoldSeconds, closeTo(1.0, 0.001));
      expect(state.bestHoldSeconds, closeTo(5.0, 0.001));
    },
  );
}

Future<void> _armAndReachPeak(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _pumpAcceptedPose(
    controller,
    detector,
    clock,
    _squatPose(angle: 170),
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    _squatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    _squatPose(angle: 90),
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );

  expect(controller.state.repCount, 0);
  expect(controller.state.currentPhase, 'PEAK');
}

Future<void> _driveUntilPhase(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
  Pose pose, {
  required String expectedPhase,
  required Duration spacing,
  int maxFrames = 12,
}) async {
  for (var index = 0; index < maxFrames; index++) {
    await _analyzeFrame(controller, detector, <Pose>[pose]);
    if (controller.state.currentPhase == expectedPhase) {
      return;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  throw TestFailure(
    'Expected phase $expectedPhase, got ${controller.state.currentPhase}',
  );
}

Future<void> _pumpAcceptedPose(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
  Pose pose, {
  required int count,
  required Duration spacing,
}) async {
  for (var index = 0; index < count; index++) {
    await _analyzeFrame(controller, detector, <Pose>[pose]);
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

Future<void> _analyzeFrame(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  List<Pose> poses,
) async {
  detector.enqueue(poses);
  await controller.processInputImageForAnalysis(_dummyInputImage());
}

InputImage _dummyInputImage() {
  return InputImage.fromBytes(
    bytes: Uint8List.fromList(<int>[0, 0, 0, 0]),
    metadata: InputImageMetadata(
      size: Size(1, 1),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: 1,
    ),
  );
}

class _QueuedPoseDetector implements PoseDetector {
  final List<List<Pose>> _queuedPoses = <List<Pose>>[];

  void enqueue(List<Pose> poses) {
    _queuedPoses.add(poses);
  }

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_queuedPoses.isEmpty) {
      throw StateError('No queued pose result for test detector.');
    }
    return _queuedPoses.removeAt(0);
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClock {
  DateTime _current = DateTime.utc(2030, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

class _ControllerHarness {
  const _ControllerHarness({
    required this.container,
    required this.subscription,
    required this.controller,
  });

  final ProviderContainer container;
  final ProviderSubscription<WorkoutState> subscription;
  final WorkoutController controller;

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

_ControllerHarness _createHarness({
  required ExerciseType exerciseType,
  required ExerciseConfig config,
  required _QueuedPoseDetector detector,
  required _FakeClock clock,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith((ref) => config),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
    ],
  );
  final subscription = container.listen<WorkoutState>(
    workoutControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  final controller = container.read(workoutControllerProvider.notifier);
  return _ControllerHarness(
    container: container,
    subscription: subscription,
    controller: controller,
  );
}

Future<void> _establishVisibleHold(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock, {
  bool rightOnly = false,
}) async {
  await _analyzeFrame(controller, detector, <Pose>[
    _plankPose(rightOnly: rightOnly),
  ]);
  clock.advance(const Duration(milliseconds: 100));
  await _analyzeFrame(controller, detector, <Pose>[
    _plankPose(rightOnly: rightOnly),
  ]);
  clock.advance(const Duration(seconds: 5));
  await _analyzeFrame(controller, detector, <Pose>[
    _plankPose(rightOnly: rightOnly),
  ]);
}

Future<void> _establishActiveLeftRepContext(
  WorkoutController controller,
  _QueuedPoseDetector detector,
  _FakeClock clock,
) async {
  await _pumpAcceptedPose(
    controller,
    detector,
    clock,
    _leftOnlyAcceptedSquatPose(angle: 170),
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  await _driveUntilPhase(
    controller,
    detector,
    clock,
    _leftOnlyAcceptedSquatPose(angle: 140),
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
}

ExerciseConfig _squatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 150,
    thresholdPeak: 95,
    formThreshold: 45,
    targetMinAngle: 70,
  );
}

ExerciseConfig _plankConfig() {
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
    holdSignals: const HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

Pose _squatPose({
  required double angle,
  double defaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final radians = angle * (3.1415926535897932 / 180.0);
  final ankleX = math.sin(radians);
  final ankleY = math.cos(radians);
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }
    landmarks[type] = _landmark(
      type,
      x,
      y,
      likelihood: likelihoodOverrides[type] ?? defaultLikelihood,
    );
  }

  addLandmark(PoseLandmarkType.leftShoulder, -1, 1);
  addLandmark(PoseLandmarkType.leftHip, 0, 1);
  addLandmark(PoseLandmarkType.leftKnee, 0, 0);
  addLandmark(PoseLandmarkType.leftAnkle, ankleX, ankleY);

  return Pose(landmarks: landmarks);
}

Pose _leftOnlyAcceptedSquatPose({required double angle}) {
  return _bilateralSquatPose(
    leftAngle: angle,
    rightAngle: angle,
    leftDefaultLikelihood: 0.95,
    rightDefaultLikelihood: 0.40,
  );
}

Pose _rightOnlyAcceptedSquatPose({
  required double leftAngle,
  required double rightAngle,
}) {
  return _bilateralSquatPose(
    leftAngle: leftAngle,
    rightAngle: rightAngle,
    leftDefaultLikelihood: 0.40,
    rightDefaultLikelihood: 0.95,
  );
}

Pose _bothAcceptedSquatPose({
  required double leftAngle,
  required double rightAngle,
  double leftDefaultLikelihood = 0.95,
  double rightDefaultLikelihood = 0.95,
}) {
  return _bilateralSquatPose(
    leftAngle: leftAngle,
    rightAngle: rightAngle,
    leftDefaultLikelihood: leftDefaultLikelihood,
    rightDefaultLikelihood: rightDefaultLikelihood,
  );
}

Pose _bilateralSquatPose({
  required double leftAngle,
  required double rightAngle,
  double leftDefaultLikelihood = 0.95,
  double rightDefaultLikelihood = 0.95,
}) {
  final leftRadians = leftAngle * (3.1415926535897932 / 180.0);
  final rightRadians = rightAngle * (3.1415926535897932 / 180.0);
  final landmarks = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      -1,
      1,
      likelihood: leftDefaultLikelihood,
    ),
    PoseLandmarkType.leftHip: _landmark(
      PoseLandmarkType.leftHip,
      0,
      1,
      likelihood: leftDefaultLikelihood,
    ),
    PoseLandmarkType.leftKnee: _landmark(
      PoseLandmarkType.leftKnee,
      0,
      0,
      likelihood: leftDefaultLikelihood,
    ),
    PoseLandmarkType.leftAnkle: _landmark(
      PoseLandmarkType.leftAnkle,
      math.sin(leftRadians),
      math.cos(leftRadians),
      likelihood: leftDefaultLikelihood,
    ),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      3,
      1,
      likelihood: rightDefaultLikelihood,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      2,
      1,
      likelihood: rightDefaultLikelihood,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      2,
      0,
      likelihood: rightDefaultLikelihood,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      2 - math.sin(rightRadians),
      math.cos(rightRadians),
      likelihood: rightDefaultLikelihood,
    ),
  };

  return Pose(landmarks: landmarks);
}

Pose _plankPose({
  double defaultLikelihood = 0.95,
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }
    landmarks[type] = _landmark(type, x, y, likelihood: defaultLikelihood);
  }

  if (rightOnly) {
    addLandmark(PoseLandmarkType.rightShoulder, 1, 0);
    addLandmark(PoseLandmarkType.rightElbow, 0.5, 0);
    addLandmark(PoseLandmarkType.rightWrist, 0.5, -1);
    addLandmark(PoseLandmarkType.rightHip, 0, 0);
    addLandmark(PoseLandmarkType.rightKnee, -0.2, 0);
    addLandmark(PoseLandmarkType.rightAnkle, -1, 0.2);
  } else {
    addLandmark(PoseLandmarkType.leftShoulder, -1, 0);
    addLandmark(PoseLandmarkType.leftElbow, -0.5, 0);
    addLandmark(PoseLandmarkType.leftWrist, -0.5, -1);
    addLandmark(PoseLandmarkType.leftHip, 0, 0);
    addLandmark(PoseLandmarkType.leftKnee, 0.2, 0);
    addLandmark(PoseLandmarkType.leftAnkle, 1, 0.2);
  }

  return Pose(landmarks: landmarks);
}

Pose _bilateralPlankPose({
  required double leftLikelihood,
  required double rightLikelihood,
  double leftBodyLineAngle = 180,
  double leftArmSupportAngle = 90,
  double leftLegExtensionAngle = 180,
  double rightBodyLineAngle = 180,
  double rightArmSupportAngle = 90,
  double rightLegExtensionAngle = 180,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(
    PoseLandmarkType type,
    double x,
    double y, {
    required double likelihood,
  }) {
    landmarks[type] = _landmark(type, x, y, likelihood: likelihood);
  }

  _addHoldSideLandmarks(
    addLandmark: addLandmark,
    side: HoldSide.left,
    shoulder: const _Point(-1, 0),
    hip: const _Point(0, 0),
    elbow: const _Point(-0.5, 0),
    bodyLineAngle: leftBodyLineAngle,
    armSupportAngle: leftArmSupportAngle,
    legExtensionAngle: leftLegExtensionAngle,
    likelihood: leftLikelihood,
  );
  _addHoldSideLandmarks(
    addLandmark: addLandmark,
    side: HoldSide.right,
    shoulder: const _Point(1, 0),
    hip: const _Point(0, 0),
    elbow: const _Point(0.5, 0),
    bodyLineAngle: rightBodyLineAngle,
    armSupportAngle: rightArmSupportAngle,
    legExtensionAngle: rightLegExtensionAngle,
    likelihood: rightLikelihood,
  );

  return Pose(landmarks: landmarks);
}

void _addHoldSideLandmarks({
  required void Function(
    PoseLandmarkType type,
    double x,
    double y, {
    required double likelihood,
  })
  addLandmark,
  required HoldSide side,
  required _Point shoulder,
  required _Point hip,
  required _Point elbow,
  required double bodyLineAngle,
  required double armSupportAngle,
  required double legExtensionAngle,
  required double likelihood,
}) {
  final bodyLineRadians = _bodyLineRadians(side, bodyLineAngle);
  final ankle = _Point(
    hip.x + math.cos(bodyLineRadians),
    hip.y + math.sin(bodyLineRadians),
  );
  final knee = _kneePoint(
    hip: hip,
    ankle: ankle,
    legExtensionAngle: legExtensionAngle,
  );
  final armSupportRadians = _armSupportRadians(side, armSupportAngle);
  final wrist = _Point(
    elbow.x + math.cos(armSupportRadians),
    elbow.y + math.sin(armSupportRadians),
  );

  if (side == HoldSide.left) {
    addLandmark(
      PoseLandmarkType.leftShoulder,
      shoulder.x,
      shoulder.y,
      likelihood: likelihood,
    );
    addLandmark(
      PoseLandmarkType.leftElbow,
      elbow.x,
      elbow.y,
      likelihood: likelihood,
    );
    addLandmark(
      PoseLandmarkType.leftWrist,
      wrist.x,
      wrist.y,
      likelihood: likelihood,
    );
    addLandmark(PoseLandmarkType.leftHip, hip.x, hip.y, likelihood: likelihood);
    addLandmark(
      PoseLandmarkType.leftKnee,
      knee.x,
      knee.y,
      likelihood: likelihood,
    );
    addLandmark(
      PoseLandmarkType.leftAnkle,
      ankle.x,
      ankle.y,
      likelihood: likelihood,
    );
    return;
  }

  addLandmark(
    PoseLandmarkType.rightShoulder,
    shoulder.x,
    shoulder.y,
    likelihood: likelihood,
  );
  addLandmark(
    PoseLandmarkType.rightElbow,
    elbow.x,
    elbow.y,
    likelihood: likelihood,
  );
  addLandmark(
    PoseLandmarkType.rightWrist,
    wrist.x,
    wrist.y,
    likelihood: likelihood,
  );
  addLandmark(PoseLandmarkType.rightHip, hip.x, hip.y, likelihood: likelihood);
  addLandmark(
    PoseLandmarkType.rightKnee,
    knee.x,
    knee.y,
    likelihood: likelihood,
  );
  addLandmark(
    PoseLandmarkType.rightAnkle,
    ankle.x,
    ankle.y,
    likelihood: likelihood,
  );
}

double _bodyLineRadians(HoldSide side, double bodyLineAngle) {
  final degrees = side == HoldSide.left ? 180.0 - bodyLineAngle : bodyLineAngle;
  return degrees * (math.pi / 180.0);
}

double _armSupportRadians(HoldSide side, double armSupportAngle) {
  final degrees = side == HoldSide.left
      ? 180.0 + armSupportAngle
      : 360.0 - armSupportAngle;
  return degrees * (math.pi / 180.0);
}

_Point _kneePoint({
  required _Point hip,
  required _Point ankle,
  required double legExtensionAngle,
}) {
  final midpoint = _Point((hip.x + ankle.x) / 2, (hip.y + ankle.y) / 2);
  final normalizedAngle = legExtensionAngle.clamp(0.0, 180.0);
  if (normalizedAngle >= 179.999) {
    return midpoint;
  }

  final dx = ankle.x - hip.x;
  final dy = ankle.y - hip.y;
  final chordLength = math.sqrt(dx * dx + dy * dy);
  if (chordLength == 0) {
    return midpoint;
  }

  final halfChord = chordLength / 2;
  final angleRadians = normalizedAngle * (math.pi / 180.0);
  final offset = halfChord / math.tan(angleRadians / 2);
  final perpendicular = _Point(-dy / chordLength, dx / chordLength);
  return _Point(
    midpoint.x + perpendicular.x * offset,
    midpoint.y + perpendicular.y * offset,
  );
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}
