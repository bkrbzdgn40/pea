import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/common_frame_pose_pipeline.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_acceptance_stabilizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart'
    show PoseQualityAssessment;
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      'direct input production path delegates to the extracted common pipeline',
      () async {
        final acceptedPose = _squatPose(angle: 170, defaultLikelihood: 0.66);
        final spyPipeline = _SpyWorkoutFramePosePipeline(
          result: FramePosePipelineResult.accepted(
            poseCount: 1,
            selectedPose: acceptedPose,
            selectedAssessment: _acceptedRangeRepAssessment(),
            didBecomeStableTracking: false,
          ),
        );
        final harness = _createHarness(
          exerciseType: ExerciseType.squat,
          config: _squatConfig(),
          detector: _QueuedPoseDetector(),
          clock: _FakeClock(),
          extraOverrides: <Override>[
            workoutFramePosePipelineFactoryProvider.overrideWithValue(({
              required PoseAcceptanceStabilizer poseAcceptanceStabilizer,
            }) {
              spyPipeline.lastPoseAcceptanceStabilizer =
                  poseAcceptanceStabilizer;
              return spyPipeline;
            }),
          ],
        );
        addTearDown(harness.dispose);

        await harness.controller.processInputImageForAnalysis(
          dummyInputImage(),
        );

        final state = harness.container.read(workoutControllerProvider);
        final snapshot = harness.controller.diagnosticsSnapshot();

        expect(spyPipeline.processInputImageCallCount, 1);
        expect(spyPipeline.lastPoseAcceptanceStabilizer, isNotNull);
        expect(spyPipeline.lastAssessPose, isNotNull);
        expect(spyPipeline.lastAssessedPose, same(acceptedPose));
        expect(spyPipeline.lastAssessedPoseQuality?.isAccepted, isTrue);
        expect(
          spyPipeline.lastAssessedPoseQuality?.acceptedRangeRepSides,
          const <RangeRepSide>{RangeRepSide.left},
        );
        expect(
          spyPipeline.lastAssessedPoseQuality?.preferredRangeRepSide,
          RangeRepSide.left,
        );
        expect(state.currentAngle, closeTo(170.0, 0.001));
        expect(state.holdFeedbackCode, isNull);
        expect(snapshot.acceptedPoseFrameCount, 1);
      },
    );

    test(
      'converter-drop diagnostics keep wall-clock timing semantics',
      () async {
        final converterDropClock = _FakeClock()
          ..advance(const Duration(days: -2500));
        final spyPipeline = _SpyWorkoutFramePosePipeline(
          result: const FramePosePipelineResult.converterDrop(),
        );
        final harness = _createHarness(
          exerciseType: ExerciseType.squat,
          config: _squatConfig(),
          detector: _QueuedPoseDetector(),
          clock: converterDropClock,
          extraOverrides: <Override>[
            workoutFramePosePipelineFactoryProvider.overrideWithValue(({
              required PoseAcceptanceStabilizer poseAcceptanceStabilizer,
            }) {
              spyPipeline.lastPoseAcceptanceStabilizer =
                  poseAcceptanceStabilizer;
              return spyPipeline;
            }),
          ],
        );
        addTearDown(harness.dispose);

        await harness.controller.processInputImageForAnalysis(
          dummyInputImage(),
        );

        final snapshot = harness.controller.diagnosticsSnapshot();

        expect(spyPipeline.processInputImageCallCount, 1);
        expect(snapshot.converterDropCount, 1);
        expect(snapshot.analysisCompletedCount, 0);
        expect(snapshot.frameProcessingMsMax, isNotNull);
        expect(snapshot.frameProcessingMsMax, greaterThan(0));
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

    test('accepted range-rep frames keep typed hold state null', () async {
      final acceptedPose = _squatPose(angle: 170, defaultLikelihood: 0.66);

      await _analyzeFrame(controller, detector, <Pose>[acceptedPose]);
      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(controller, detector, <Pose>[acceptedPose]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();
      final json = snapshot.toJson();

      expect(snapshot.acceptedPoseFrameCount, 1);
      expect(state.currentAngle, closeTo(170.0, 0.001));

      expect(state.holdFeedbackCode, isNull);
      expect(state.holdEnginePhase, isNull);
      expect(state.selectedHoldSide, isNull);

      expect(snapshot.presentedHoldFeedbackCode, isNull);
      expect(snapshot.engineHoldFeedbackCode, isNull);
      expect(snapshot.holdEnginePhase, isNull);
      expect(snapshot.currentHoldSide, isNull);
      expect(snapshot.lastVisibleHoldPosture, isNull);
      expect(snapshot.isHoldFormBreakGraceActive, isNull);
      expect(snapshot.isHoldVisibilitySuspended, isNull);

      expect(json['presented_hold_feedback_code'], isNull);
      expect(json['engine_hold_feedback_code'], isNull);
      expect(json['hold_engine_phase'], isNull);
      expect(json['current_hold_side'], isNull);
      expect(json['hold_has_complete_metrics'], isNull);
      expect(json['hold_has_active_posture'], isNull);
      expect(json['hold_is_body_aligned'], isNull);
      expect(json['hold_is_arm_supported'], isNull);
      expect(json['hold_are_legs_extended'], isNull);
      expect(json['hold_is_form_break_grace_active'], isNull);
      expect(json['hold_is_visibility_suspended'], isNull);
    });

    test('range-rep production path delegates through RangeRepCoordinator and '
        'keeps the real engine outcome', () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      late _SpyRangeRepCoordinator spyCoordinator;
      final harness = _createHarness(
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        detector: detector,
        clock: clock,
        extraOverrides: <Override>[
          rangeRepCoordinatorFactoryProvider.overrideWithValue(({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
          }) {
            spyCoordinator = _SpyRangeRepCoordinator(
              inner: DefaultRangeRepCoordinator(
                engine: engine,
                config: config,
                rangeRepContract: rangeRepContract,
              ),
            );
            return spyCoordinator;
          }),
        ],
      );
      addTearDown(harness.dispose);

      await _pumpAcceptedPose(
        harness.controller,
        detector,
        clock,
        _squatPose(angle: 170),
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        _squatPose(angle: 140),
        expectedPhase: 'DESCENDING',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        _squatPose(angle: 90),
        expectedPhase: 'PEAK',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        _squatPose(angle: 110),
        expectedPhase: 'ASCENDING',
        spacing: const Duration(milliseconds: 90),
      );
      await _driveUntilPhase(
        harness.controller,
        detector,
        clock,
        _squatPose(angle: 170),
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      final state = harness.container.read(workoutControllerProvider);

      expect(spyCoordinator.processFrameCallCount, greaterThan(0));
      expect(
        spyCoordinator.lastProcessFrameResult?.stateSnapshot.repCount,
        equals(1),
      );
      expect(state.rangeRepAnalysis, isNotNull);
      expect(state.holdAnalysis, isNull);
      expect(state.repCount, 1);
      expect(
        state.calibrationMetrics.lastRangeRepValidationStatus,
        equals('valid'),
      );
      expect(
        state.calibrationMetrics.lastRangeRepSummaryCompletedPhaseSequence,
        isTrue,
      );
    });

    test(
      'push-up production path reaches the real range-rep engine path',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        final harness = _createHarness(
          exerciseType: ExerciseType.pushUp,
          config: _pushUpConfig(),
          detector: detector,
          clock: clock,
        );
        addTearDown(harness.dispose);

        await _pumpAcceptedPose(
          harness.controller,
          detector,
          clock,
          _pushUpPose(),
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );

        var state = harness.container.read(workoutControllerProvider);
        final diagnostics = harness.controller.diagnosticsSnapshot();

        expect(diagnostics.acceptedPoseFrameCount, greaterThan(0));
        expect(state.rangeRepAnalysis, isNotNull);
        expect(state.holdAnalysis, isNull);
        expect(state.currentAngle, closeTo(90.0, 0.001));
        expect(state.currentPhase, 'AWAITING_NEUTRAL');
        expect(state.repCount, 0);
      },
    );

    test(
      'sit-up production path resolves the real config and publishes typed range-rep state',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        final harness = await _createResolvedConfigHarness(
          selectedExercise: ExerciseType.sitUp,
          detector: detector,
          clock: clock,
        );
        addTearDown(harness.dispose);

        expect(
          harness.container.read(exerciseConfigProvider).requireValue.name,
          'Sit-up',
        );

        await _pumpAcceptedPose(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 125, formAngle: 90),
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 108, formAngle: 90),
          expectedPhase: 'DESCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 68, formAngle: 90),
          expectedPhase: 'PEAK',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 82, formAngle: 90),
          expectedPhase: 'ASCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 121, formAngle: 90),
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        final state = harness.container.read(workoutControllerProvider);
        final diagnostics = harness.controller.diagnosticsSnapshot();

        expect(state.rangeRepAnalysis, isNotNull);
        expect(state.holdAnalysis, isNull);
        expect(state.repCount, 1);
        expect(state.currentPhase, 'NEUTRAL');
        expect(state.currentAngle, closeTo(121.0, 0.001));
        expect(
          state.calibrationMetrics.lastRangeRepValidatedRepIndex,
          equals(1),
        );
        expect(
          state.calibrationMetrics.lastRangeRepValidationStatus,
          equals('valid'),
        );
        expect(state.calibrationMetrics.baseFormThreshold, 60.0);
        expect(state.calibrationMetrics.effectiveFormThreshold, 60.0);
        expect(
          state.calibrationMetrics.lastRangeRepSummaryHadFormViolation,
          isFalse,
        );
        expect(diagnostics.analysisKind, 'rangeRep');
        expect(diagnostics.acceptedPoseFrameCount, greaterThan(0));
      },
    );

    test(
      'sit-up production path keeps a normal peak form metric out of the warning even after a high baseline',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        final harness = await _createResolvedConfigHarness(
          selectedExercise: ExerciseType.sitUp,
          detector: detector,
          clock: clock,
        );
        addTearDown(harness.dispose);

        await _pumpAcceptedPose(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 125, formAngle: 120),
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 108, formAngle: 68.4),
          expectedPhase: 'DESCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(primaryAngle: 52.7, formAngle: 68.4),
          expectedPhase: 'PEAK',
          spacing: const Duration(milliseconds: 90),
        );

        final state = harness.container.read(workoutControllerProvider);
        final metrics = state.calibrationMetrics;

        expect(state.currentPhase, 'PEAK');
        expect(state.isFormBad, isFalse);
        expect(state.currentAngle, lessThan(70.0));
        expect(state.feedbackMessage, isNot('Bacak acini koru.'));
        expect(metrics.baseFormThreshold, 60.0);
        expect(metrics.effectiveFormThreshold, 60.0);
        expect(metrics.calibrationThresholdOffsetApplied, isFalse);
        expect(metrics.calibrationThresholdOffsetCandidate, isNull);
        expect(
          metrics.calibrationThresholdOffsetFallbackReason,
          'disabled_by_contract',
        );
        expect(
          metrics.sessionCalibrationBaselineCandidate?.formMetricBaseline,
          greaterThan(80.0),
        );
      },
    );

    test(
      'sit-up production path keeps an advisory low-likelihood ankle out of body-not-visible fallback',
      () async {
        final detector = _QueuedPoseDetector();
        final clock = _FakeClock();
        final harness = await _createResolvedConfigHarness(
          selectedExercise: ExerciseType.sitUp,
          detector: detector,
          clock: clock,
        );
        addTearDown(harness.dispose);

        const ankleLowLikelihood = <PoseLandmarkType, double>{
          PoseLandmarkType.leftAnkle: 0.10,
        };

        await _pumpAcceptedPose(
          harness.controller,
          detector,
          clock,
          _sitUpPose(
            primaryAngle: 125,
            formAngle: 90,
            includeRightSide: false,
            likelihoodOverrides: ankleLowLikelihood,
          ),
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(
            primaryAngle: 108,
            formAngle: 90,
            includeRightSide: false,
            likelihoodOverrides: ankleLowLikelihood,
          ),
          expectedPhase: 'DESCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(
            primaryAngle: 68,
            formAngle: 90,
            includeRightSide: false,
            likelihoodOverrides: ankleLowLikelihood,
          ),
          expectedPhase: 'PEAK',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(
            primaryAngle: 82,
            formAngle: 90,
            includeRightSide: false,
            likelihoodOverrides: ankleLowLikelihood,
          ),
          expectedPhase: 'ASCENDING',
          spacing: const Duration(milliseconds: 90),
        );
        await _driveUntilPhase(
          harness.controller,
          detector,
          clock,
          _sitUpPose(
            primaryAngle: 121,
            formAngle: 90,
            includeRightSide: false,
            likelihoodOverrides: ankleLowLikelihood,
          ),
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        final state = harness.container.read(workoutControllerProvider);
        final diagnostics = harness.controller.diagnosticsSnapshot();

        expect(state.repCount, 1);
        expect(state.currentPhase, 'NEUTRAL');
        expect(state.feedbackMessage, isNot('Vucut net gorunmuyor.'));
        expect(diagnostics.rejectedPoseFrameCount, 0);
        expect(diagnostics.acceptedPoseFrameCount, greaterThan(0));
      },
    );

    test(
      'completed clean rep records a valid production validation outcome',
      () async {
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
        final metrics = state.calibrationMetrics;

        expect(state.repCount, 1);
        expect(metrics.lastRangeRepValidationStatus, 'valid');
        expect(metrics.lastRangeRepValidationReasons, isEmpty);
        expect(metrics.lastRangeRepValidatedRepIndex, 1);
        expect(metrics.rangeRepValidatedCount, 1);
        expect(metrics.rangeRepLowConfidenceCount, 0);
        expect(metrics.rangeRepInvalidCount, 0);
        expect(metrics.hasLastRangeRepSummary, isTrue);
        expect(metrics.lastRangeRepSummaryCompletedPhaseSequence, isTrue);
        expect(metrics.lastRangeRepSummarySelectedSideLabel, 'left');
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

    test('range-rep lifecycle interruption delegates to the coordinator and '
        'forces fresh neutral reacquisition', () async {
      final detector = _QueuedPoseDetector();
      final clock = _FakeClock();
      late _SpyRangeRepCoordinator spyCoordinator;
      final harness = _createHarness(
        exerciseType: ExerciseType.squat,
        config: _squatConfig(),
        detector: detector,
        clock: clock,
        extraOverrides: <Override>[
          rangeRepCoordinatorFactoryProvider.overrideWithValue(({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
          }) {
            spyCoordinator = _SpyRangeRepCoordinator(
              inner: DefaultRangeRepCoordinator(
                engine: engine,
                config: config,
                rangeRepContract: rangeRepContract,
              ),
            );
            return spyCoordinator;
          }),
        ],
      );
      addTearDown(harness.dispose);

      await _establishActiveLeftRepContext(harness.controller, detector, clock);

      harness.controller.handleLifecycleInterruption(reason: 'paused');

      var state = harness.container.read(workoutControllerProvider);

      expect(spyCoordinator.handleLifecycleInterruptionCallCount, 1);
      expect(spyCoordinator.diagnosticsState().selectedSideLabel, isNull);
      expect(spyCoordinator.diagnosticsState().hasActiveRepContext, isFalse);
      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');

      await _analyzeFrame(harness.controller, detector, <Pose>[
        _squatPose(angle: 90),
      ]);
      state = harness.container.read(workoutControllerProvider);

      expect(state.repCount, 0);
      expect(state.currentPhase, 'WAITING');

      clock.advance(const Duration(milliseconds: 100));
      await _analyzeFrame(harness.controller, detector, <Pose>[
        _squatPose(angle: 90),
      ]);
      state = harness.container.read(workoutControllerProvider);

      expect(state.repCount, 0);
      expect(state.currentPhase, 'AWAITING_NEUTRAL');
    });
  });

  test('hold production path delegates through HoldCoordinator and keeps the '
      'real engine outcome', () async {
    final detector = _QueuedPoseDetector();
    final clock = _FakeClock();
    late _SpyHoldCoordinator spyCoordinator;
    final harness = _createHarness(
      exerciseType: ExerciseType.plank,
      config: _plankConfig(),
      detector: detector,
      clock: clock,
      extraOverrides: <Override>[
        holdCoordinatorFactoryProvider.overrideWithValue(({
          required HoldAnalysisEngine engine,
          required ExerciseConfig config,
        }) {
          spyCoordinator = _SpyHoldCoordinator(
            inner: DefaultHoldCoordinator(engine: engine, config: config),
          );
          return spyCoordinator;
        }),
      ],
    );
    addTearDown(harness.dispose);

    await _establishVisibleHold(harness.controller, detector, clock);

    final state = harness.container.read(workoutControllerProvider);

    expect(
      spyCoordinator.selectHoldSideForAcceptedPoseCallCount,
      greaterThan(0),
    );
    expect(
      spyCoordinator.requiredHoldSideForAssessmentCallCount,
      greaterThan(0),
    );
    expect(spyCoordinator.processFrameCallCount, greaterThan(0));
    expect(spyCoordinator.lastSelectedHoldSide, HoldSide.left);
    expect(
      spyCoordinator.lastProcessFrameResult?.stateSnapshot.isHolding,
      isTrue,
    );
    expect(
      spyCoordinator.lastProcessFrameResult?.stateSnapshot.currentHoldSeconds,
      closeTo(5.0, 0.001),
    );
    expect(state.holdAnalysis, isNotNull);
    expect(state.rangeRepAnalysis, isNull);
    expect(state.selectedHoldSide, HoldSide.left);
    expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
    expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
    expect(state.holdEnginePhase, HoldPhase.holding);
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
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.holdAnalysis, isNotNull);
      expect(state.rangeRepAnalysis, isNull);
      expect(state.selectedHoldSide, HoldSide.left);
      expect(state.isHolding, isTrue);
      expect(state.repCount, 0);
      expect(state.lastRepScore, 0);
      expect(state.lastRepROM, 0);
      expect(state.holdFeedbackCode, HoldFeedbackCode.holdPosition);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Pozisyonu Koru');
      expect(state.currentPhase, 'HOLDING');
      expect(state.calibrationMetrics.selectedRangeRepSide, isNull);
      expect(state.calibrationMetrics.lastRangeRepValidationStatus, isNull);
      expect(state.calibrationMetrics.lastRangeRepValidatedRepIndex, isNull);
      expect(state.calibrationMetrics.hasLastRangeRepSummary, isFalse);
      expect(snapshot.currentSelectedSide, isNull);
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

  test(
    'hold body misalignment keeps the active hold during the grace window',
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

      clock.advance(const Duration(milliseconds: 150));
      await _analyzeFrame(controller, detector, <Pose>[
        _bodyMisalignedLeftPose(leftBodyLineAngle: 120),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.currentHoldSeconds, closeTo(5.0, 0.001));
      expect(state.isHolding, isTrue);
      expect(state.hadHoldFormBreak, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.alignHips);
      expect(state.holdEnginePhase, HoldPhase.holding);
      expect(state.feedbackMessage, 'Kalcayi Hizala');
      expect(state.currentPhase, 'HOLDING');
      expect(snapshot.lastVisibleHoldPosture, isNotNull);
      expect(snapshot.lastVisibleHoldPosture?.hasActivePosture, isFalse);
      expect(snapshot.lastVisibleHoldPosture?.isBodyAligned, isFalse);
      expect(snapshot.isHoldFormBreakGraceActive, isTrue);
    },
  );

  test(
    'hold body misalignment at the 300 ms grace boundary returns to READY when posture is no longer active',
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

      await _analyzeFrame(controller, detector, <Pose>[
        _bodyMisalignedLeftPose(leftBodyLineAngle: 120),
      ]);
      clock.advance(const Duration(milliseconds: 300));
      await _analyzeFrame(controller, detector, <Pose>[
        _bodyMisalignedLeftPose(leftBodyLineAngle: 180),
      ]);

      final state = container.read(workoutControllerProvider);
      final snapshot = controller.diagnosticsSnapshot();

      expect(state.isHolding, isFalse);
      expect(state.currentHoldSeconds, 0);
      expect(state.hadHoldFormBreak, isFalse);
      expect(state.holdFeedbackCode, HoldFeedbackCode.preparePosition);
      expect(state.holdEnginePhase, HoldPhase.ready);
      expect(state.feedbackMessage, 'Pozisyonu Hazirla');
      expect(state.currentPhase, 'READY');
      expect(snapshot.lastVisibleHoldPosture, isNotNull);
      expect(snapshot.lastVisibleHoldPosture?.hasActivePosture, isFalse);
      expect(snapshot.lastVisibleHoldPosture?.isBodyAligned, isFalse);
      expect(snapshot.isHoldFormBreakGraceActive, isFalse);
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
  await analyzeFrame(controller, detector, poses);
}

class _QueuedPoseDetector extends TestQueuedPoseDetector {}

class _FakeClock extends TestFakeClock {}

class _SpyWorkoutFramePosePipeline extends WorkoutFramePosePipeline {
  _SpyWorkoutFramePosePipeline({required this.result});

  final FramePosePipelineResult result;

  int processInputImageCallCount = 0;
  InputImage? lastInputImage;
  PoseAcceptanceStabilizer? lastPoseAcceptanceStabilizer;
  PoseQualityAssessor? lastAssessPose;
  Pose? lastAssessedPose;
  PoseQualityAssessment? lastAssessedPoseQuality;

  @override
  Future<FramePosePipelineResult> processInputImage({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    processInputImageCallCount += 1;
    lastInputImage = inputImage;
    lastAssessPose = assessPose;
    if (result.selectedPose != null) {
      lastAssessedPose = result.selectedPose;
      lastAssessedPoseQuality = assessPose(result.selectedPose!);
    }
    return result;
  }
}

class _SpyRangeRepCoordinator implements RangeRepCoordinator {
  _SpyRangeRepCoordinator({required this.inner});

  final RangeRepCoordinator inner;

  int processFrameCallCount = 0;
  int handleLifecycleInterruptionCallCount = 0;
  RangeRepCoordinatorFrameResult? lastProcessFrameResult;
  RangeRepCoordinatorStateSnapshot? lastLifecycleSnapshot;

  @override
  RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    handleLifecycleInterruptionCallCount += 1;
    lastLifecycleSnapshot = inner.handleLifecycleInterruption(reason: reason);
    return lastLifecycleSnapshot!;
  }

  @override
  RangeRepCoordinatorDiagnosticsState diagnosticsState() {
    return inner.diagnosticsState();
  }

  @override
  RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    processFrameCallCount += 1;
    lastProcessFrameResult = inner.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    return lastProcessFrameResult!;
  }
}

class _SpyHoldCoordinator implements HoldCoordinator {
  _SpyHoldCoordinator({required this.inner});

  final HoldCoordinator inner;

  int requiredHoldSideForAssessmentCallCount = 0;
  int selectHoldSideForAcceptedPoseCallCount = 0;
  int processFrameCallCount = 0;
  int handleLifecycleInterruptionCallCount = 0;
  HoldSide? lastSelectedHoldSide;
  HoldCoordinatorFrameResult? lastProcessFrameResult;
  HoldCoordinatorStateSnapshot? lastLifecycleSnapshot;

  @override
  HoldCoordinatorStateSnapshot currentStateSnapshot() {
    return inner.currentStateSnapshot();
  }

  @override
  HoldDiagnosticsSnapshot diagnosticsSnapshot() {
    return inner.diagnosticsSnapshot();
  }

  @override
  HoldCoordinatorStateSnapshot handleLifecycleInterruption({String? reason}) {
    handleLifecycleInterruptionCallCount += 1;
    lastLifecycleSnapshot = inner.handleLifecycleInterruption(reason: reason);
    return lastLifecycleSnapshot!;
  }

  @override
  HoldCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
  }) {
    processFrameCallCount += 1;
    lastProcessFrameResult = inner.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
    );
    return lastProcessFrameResult!;
  }

  @override
  HoldSide? requiredHoldSideForAssessment() {
    requiredHoldSideForAssessmentCallCount += 1;
    return inner.requiredHoldSideForAssessment();
  }

  @override
  HoldSide selectHoldSideForAcceptedPose(PoseQualityAssessment assessment) {
    selectHoldSideForAcceptedPoseCallCount += 1;
    lastSelectedHoldSide = inner.selectHoldSideForAcceptedPose(assessment);
    return lastSelectedHoldSide!;
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
  List<Override> extraOverrides = const <Override>[],
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      activeAnalysisExerciseProvider.overrideWithValue(exerciseType),
      exerciseConfigProvider.overrideWith((ref) => config),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
      ...extraOverrides,
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

Future<_ControllerHarness> _createResolvedConfigHarness({
  required ExerciseType selectedExercise,
  required _QueuedPoseDetector detector,
  required _FakeClock clock,
  List<Override> extraOverrides = const <Override>[],
}) async {
  final container = ProviderContainer(
    overrides: <Override>[
      selectedExerciseProvider.overrideWith((ref) => selectedExercise),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
      ...extraOverrides,
    ],
  );
  await container.read(exerciseConfigProvider.future);
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
  return buildSquatConfig();
}

ExerciseConfig _plankConfig() {
  return buildPlankConfig();
}

ExerciseConfig _pushUpConfig() {
  final rawJson = File(
    'assets/config/exercises/push_up.json',
  ).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
}

Pose _sitUpPose({
  required double primaryAngle,
  double formAngle = 90,
  bool includeLeftSide = true,
  bool includeRightSide = true,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  return buildSitUpPose(
    primaryAngle: primaryAngle,
    formAngle: formAngle,
    includeLeftSide: includeLeftSide,
    includeRightSide: includeRightSide,
    likelihoodOverrides: likelihoodOverrides,
    missingLandmarks: missingLandmarks,
  );
}

Pose _squatPose({
  required double angle,
  double defaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  return buildSquatPose(
    angle: angle,
    defaultLikelihood: defaultLikelihood,
    likelihoodOverrides: likelihoodOverrides,
    missingLandmarks: missingLandmarks,
  );
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

Pose _pushUpPose({double defaultLikelihood = 0.95}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        1,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        1,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        2,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        4,
        2,
        likelihood: defaultLikelihood,
      ),
    },
  );
}

Pose _plankPose({
  double defaultLikelihood = 0.95,
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  return buildPlankPose(
    defaultLikelihood: defaultLikelihood,
    missingLandmarks: missingLandmarks,
    rightOnly: rightOnly,
  );
}

Pose _bodyMisalignedLeftPose({required double leftBodyLineAngle}) {
  return _bilateralPlankPose(
    leftLikelihood: 0.99,
    rightLikelihood: 0.40,
    leftBodyLineAngle: leftBodyLineAngle,
  );
}

PoseQualityAssessment _acceptedRangeRepAssessment() {
  return PoseQualityAssessment(
    isAccepted: true,
    minimumRequiredLikelihood: 0.66,
    meanRequiredLikelihood: 0.66,
    requiredLandmarkCount: 4,
    acceptedLandmarkCount: 4,
    acceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
    qualityScore: 1006.66,
  );
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
  return buildLandmark(type, x, y, likelihood: likelihood);
}

class _Point {
  const _Point(this.x, this.y);

  final double x;
  final double y;
}
