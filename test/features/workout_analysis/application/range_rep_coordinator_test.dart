import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_outcome_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_technique_evaluator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_technique_history_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_completed_rep_detection_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_confirmed_transition.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_score_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('DefaultRangeRepCoordinator', () {
    test('drives the real range-rep engine through a validated clean rep', () {
      final clock = _TestClock();
      final coordinator = _buildCoordinator(clock);

      _pumpAcceptedFrames(
        coordinator,
        clock,
        angle: 170,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      final descendingResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 140,
        expectedPhase: 'DESCENDING',
      );
      final peakResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 90,
        expectedPhase: 'PEAK',
      );
      final ascendingResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 110,
        expectedPhase: 'ASCENDING',
      );
      final completedResult = _driveUntilPhase(
        coordinator,
        clock,
        angle: 170,
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      expect(descendingResult.stateSnapshot.currentPhase, 'DESCENDING');
      expect(peakResult.stateSnapshot.currentPhase, 'PEAK');
      expect(ascendingResult.stateSnapshot.currentPhase, 'ASCENDING');
      expect(completedResult.stateSnapshot.repCount, 1);
      expect(completedResult.stateSnapshot.currentPhase, 'NEUTRAL');
      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        'valid',
      );
      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepSummaryCompletedPhaseSequence,
        isTrue,
      );
      expect(
        completedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
        'left',
      );
      expect(
        completedResult.stateSnapshot.calibrationMetrics.analysisKind.name,
        'rangeRep',
      );
      expect(completedResult.diagnosticsUpdate.recordAcceptedPoseFrame, isTrue);
    });

    test('uses the supplied config for its default validation tracker', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        now: clock.now,
      );
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 0.0,
        ),
      );

      final completedResult = _completeCleanSquatRep(coordinator, clock);
      final calibrationMetrics =
          completedResult.stateSnapshot.calibrationMetrics;

      expect(calibrationMetrics.lastRangeRepValidationStatus, 'invalid');
      expect(
        calibrationMetrics.lastRangeRepValidationReasons,
        contains('insufficient rom'),
      );
      expect(calibrationMetrics.rangeRepInvalidCount, 1);
      expect(completedResult.stateSnapshot.repCount, 0);
      expect(completedResult.stateSnapshot.lastRepScore, 0);
      expect(completedResult.stateSnapshot.lastRepRom, 0);
    });

    test('keeps tempo-only completions valid and diagnostic', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        now: clock.now,
      );
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minDescentMillis: 10000,
        ),
      );

      final completedResult = _completeCleanSquatRep(coordinator, clock);

      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        'valid',
      );
      expect(completedResult.stateSnapshot.repCount, 1);
      expect(completedResult.validatedRepEvent, isNotNull);
      expect(completedResult.validatedRepEvent!.attemptIndex, 1);
      expect(completedResult.validatedRepEvent!.acceptedRepIndex, 1);
      expect(completedResult.validatedRepEvent!.countsTowardReps, isTrue);
      expect(
        completedResult.validatedRepEvent!.validationStatus,
        RangeRepValidationStatus.valid,
      );
      final calibrationMetrics =
          completedResult.stateSnapshot.calibrationMetrics;
      expect(
        completedResult.stateSnapshot.lastRepScore,
        closeTo(calibrationMetrics.lastRepRomScore, 0.001),
      );
      expect(
        calibrationMetrics.lastRepDescentScore,
        lessThan(calibrationMetrics.lastRepRomScore),
      );
      expect(
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .rangeRepLowConfidenceCount,
        0,
      );
      expect(
        completedResult.diagnosticsUpdate.completedRepValidationReasons,
        isEmpty,
      );
      expect(
        completedResult.diagnosticsUpdate.completedRepTempoDiagnosticReasons,
        contains(RangeRepValidationReason.excessiveDescentSpeed.name),
      );
    });

    test('reuses completed-rep telemetry between ordinary runtime frames', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        now: clock.now,
      );
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 0.0,
        ),
      );

      final completedResult = _completeCleanSquatRep(coordinator, clock);
      final completedReasons = completedResult
          .stateSnapshot
          .calibrationMetrics
          .lastRangeRepValidationReasons;
      expect(completedReasons, isNotEmpty);

      clock.advance(const Duration(milliseconds: 120));
      final nextRuntimeFrame = _processAcceptedFrame(
        coordinator,
        clock,
        angle: 170,
      );

      expect(
        identical(
          nextRuntimeFrame
              .stateSnapshot
              .calibrationMetrics
              .lastRangeRepValidationReasons,
          completedReasons,
        ),
        isTrue,
      );
      expect(
        nextRuntimeFrame
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        completedResult
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
      );
    });

    test('keeps an explicitly injected outcome tracker unchanged', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        now: clock.now,
      );
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(
          minAcceptableRomAngle: 0.0,
        ),
        outcomeTracker: RangeRepRepOutcomeTracker(
          validationPolicy: const RangeRepValidationPolicy(
            config: RangeRepValidationConfig(minAcceptableRomAngle: 180.0),
          ),
        ),
      );

      final completedResult = _completeCleanSquatRep(coordinator, clock);
      final calibrationMetrics =
          completedResult.stateSnapshot.calibrationMetrics;

      expect(calibrationMetrics.lastRangeRepValidationStatus, 'valid');
      expect(calibrationMetrics.rangeRepValidatedCount, 1);
      expect(calibrationMetrics.rangeRepInvalidCount, 0);
    });

    test(
      'keeps calibration correction candidates out of the technique metric and calls only the detection engine API',
      () {
        const cases =
            <
              ({
                double finalRawMetric,
                double expectedTechniqueMetric,
                bool hasViolation,
              })
            >[
              (
                finalRawMetric: 49.0,
                expectedTechniqueMetric: 49.75,
                hasViolation: false,
              ),
              (
                finalRawMetric: 50.0,
                expectedTechniqueMetric: 50.0,
                hasViolation: false,
              ),
              (
                finalRawMetric: 51.0,
                expectedTechniqueMetric: 50.25,
                hasViolation: false,
              ),
            ];

        for (final testCase in cases) {
          final clock = _TestClock();
          final config = _squatConfig();
          final engine = _RecordingRangeRepEngine(
            config: config,
            now: clock.now,
          );
          final evaluator = _RecordingTechniqueEvaluator();
          final coordinator = DefaultRangeRepCoordinator(
            engine: engine,
            config: config,
            rangeRepContract: RangeRepContracts.squat,
            rangeRepValidationConfig: const RangeRepValidationConfig(),
            techniqueEvaluator: evaluator,
          );

          _pumpAcceptedFrames(
            coordinator,
            clock,
            angle: 170,
            formMetric: 50,
            count: 3,
            spacing: Duration.zero,
          );
          _processAcceptedFrame(
            coordinator,
            clock,
            angle: 170,
            formMetric: testCase.finalRawMetric,
          );

          expect(evaluator.formMetrics, hasLength(4));
          expect(engine.detectionUpdateCount, 4);
          expect(engine.typedUpdateCount, 0);
          expect(engine.legacyUpdateCount, 0);
          expect(
            evaluator.formMetrics.last,
            closeTo(testCase.expectedTechniqueMetric, 0.001),
          );
          expect(engine.primaryMetrics.last, closeTo(170.0, 0.001));
          expect(engine.observationTimes.last, clock.now());
          expect(
            evaluator.assessments.last.hasObservations,
            testCase.hasViolation,
          );
        }
      },
    );

    test('gates the legacy form evaluator by the contract technique role', () {
      final sitUpClock = _TestClock();
      final sitUpConfig = loadExerciseConfig(
        'assets/config/exercises/sit_up.json',
      );
      final sitUpEvaluator = _RecordingTechniqueEvaluator();
      final sitUpCoordinator = DefaultRangeRepCoordinator(
        engine: _ScriptedRangeRepEngine(
          config: sitUpConfig,
          now: sitUpClock.now,
          results: <RangeRepEngineFrameResult>[_scriptedArmedFrame()],
        ),
        config: sitUpConfig,
        rangeRepContract: RangeRepContracts.sitUp,
        rangeRepValidationConfig: const RangeRepValidationConfig(),
        techniqueEvaluator: sitUpEvaluator,
      );

      final sitUpResult = _processAcceptedFrame(
        sitUpCoordinator,
        sitUpClock,
        angle: 120,
        formMetric: 40,
      );

      expect(sitUpEvaluator.formMetrics, isEmpty);
      expect(sitUpResult.stateSnapshot.isFormBad, isFalse);
      expect(
        sitUpResult.stateSnapshot.feedbackDirective.feedbackCode,
        isNot(RangeRepFeedbackCode.keepBodyUpright),
      );

      final squatClock = _TestClock();
      final squatConfig = _squatConfig();
      final squatEvaluator = _RecordingTechniqueEvaluator();
      final squatCoordinator = DefaultRangeRepCoordinator(
        engine: _ScriptedRangeRepEngine(
          config: squatConfig,
          now: squatClock.now,
          results: <RangeRepEngineFrameResult>[_scriptedArmedFrame()],
        ),
        config: squatConfig,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(),
        techniqueEvaluator: squatEvaluator,
      );

      final squatResult = _processAcceptedFrame(
        squatCoordinator,
        squatClock,
        angle: 120,
        formMetric: 40,
      );

      expect(squatEvaluator.formMetrics, <double>[40.0]);
      expect(squatEvaluator.assessments.single.hasObservations, isTrue);
      expect(squatResult.stateSnapshot.isFormBad, isTrue);
      expect(
        squatResult.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.keepBodyUpright,
      );
    });

    test(
      'Jumping Jack evaluates coordination near peak and clears recovered feedback',
      () {
        final clock = _TestClock();
        final config = loadExerciseConfig(
          'assets/config/exercises/jumping_jack.json',
        );
        final evaluator = _RecordingTechniqueEvaluator();
        final engine = _ScriptedRangeRepEngine(
          config: config,
          primaryMetricDirection:
              RangeRepContracts.jumpingJack.primaryMetricDirection,
          now: clock.now,
          results: <RangeRepEngineFrameResult>[
            _scriptedTransition(
              RangeRepConfirmedTransitionType.acquireNeutral,
              clock.now(),
              wasArmedAtFrameStart: false,
            ),
            _scriptedArmedFrame(),
            _scriptedTransition(
              RangeRepConfirmedTransitionType.startDescending,
              clock.now().add(const Duration(milliseconds: 120)),
              repStarted: true,
              phases: const <RangeRepPhase>[RangeRepPhase.descending],
            ),
            _scriptedTransition(
              RangeRepConfirmedTransitionType.reachPeak,
              clock.now().add(const Duration(milliseconds: 240)),
              phases: const <RangeRepPhase>[RangeRepPhase.peak],
            ),
            RangeRepEngineFrameResult(
              wasArmedAtFrameStart: true,
              isArmedAfterUpdate: true,
              observedRepPhases: const <RangeRepPhase>[RangeRepPhase.peak],
            ),
          ],
        );
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: RangeRepContracts.jumpingJack,
          rangeRepValidationConfig: const RangeRepValidationConfig(),
          techniqueEvaluator: evaluator,
        );

        final acquired = _processAcceptedJumpingJackFrame(
          coordinator,
          clock,
          primaryMetric: 15,
          formMetric: 90,
        );
        clock.advance(const Duration(milliseconds: 120));
        final neutral = _processAcceptedJumpingJackFrame(
          coordinator,
          clock,
          primaryMetric: 15,
          formMetric: 90,
        );
        clock.advance(const Duration(milliseconds: 120));
        final active = _processAcceptedJumpingJackFrame(
          coordinator,
          clock,
          primaryMetric: 100,
          formMetric: 90,
        );
        clock.advance(const Duration(milliseconds: 120));
        final unsynchronizedPeak = _processAcceptedJumpingJackFrame(
          coordinator,
          clock,
          primaryMetric: 125,
          formMetric: 90,
        );
        clock.advance(const Duration(milliseconds: 120));
        final recoveredPeak = _processAcceptedJumpingJackFrame(
          coordinator,
          clock,
          primaryMetric: 125,
          formMetric: 100,
        );

        expect(evaluator.formMetrics, <double>[90.0, 100.0]);
        expect(acquired.stateSnapshot.isFormBad, isFalse);
        expect(
          acquired.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.ready,
        );
        expect(neutral.stateSnapshot.isFormBad, isFalse);
        expect(
          neutral.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.ready,
        );
        expect(active.stateSnapshot.isFormBad, isFalse);
        expect(
          active.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.descend,
        );
        expect(unsynchronizedPeak.stateSnapshot.isFormBad, isTrue);
        expect(
          unsynchronizedPeak.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.legacyFormThresholdViolation,
        );
        expect(recoveredPeak.stateSnapshot.isFormBad, isFalse);
        expect(
          recoveredPeak.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.ascend,
        );
      },
    );

    test('owns live form and feedback across the production lifecycle', () {
      final clock = _TestClock();
      final base = clock.now();
      final config = _squatConfig();
      final engine = _ScriptedRangeRepEngine(
        config: config,
        now: clock.now,
        results: <RangeRepEngineFrameResult>[
          _scriptedTransition(
            RangeRepConfirmedTransitionType.acquireNeutral,
            base,
            wasArmedAtFrameStart: false,
          ),
          _scriptedArmedFrame(),
          _scriptedArmedFrame(),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.startDescending,
            base.add(const Duration(seconds: 3)),
            repStarted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.reachPeak,
            base.add(const Duration(seconds: 4)),
            phases: const <RangeRepPhase>[
              RangeRepPhase.descending,
              RangeRepPhase.peak,
            ],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.startAscending,
            base.add(const Duration(seconds: 5)),
            phases: const <RangeRepPhase>[
              RangeRepPhase.peak,
              RangeRepPhase.ascending,
            ],
          ),
          _scriptedCompletion(
            base.add(const Duration(seconds: 6)),
            repIndex: 1,
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.startDescending,
            base.add(const Duration(seconds: 7)),
            repStarted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.abortToNeutral,
            base.add(const Duration(seconds: 8)),
            repAborted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.startDescending,
            base.add(const Duration(seconds: 9)),
            repStarted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.reachPeak,
            base.add(const Duration(seconds: 10)),
            phases: const <RangeRepPhase>[
              RangeRepPhase.descending,
              RangeRepPhase.peak,
            ],
          ),
          _scriptedTransition(
            RangeRepConfirmedTransitionType.startAscending,
            base.add(const Duration(seconds: 11)),
            phases: const <RangeRepPhase>[
              RangeRepPhase.peak,
              RangeRepPhase.ascending,
            ],
          ),
          _scriptedCompletion(
            base.add(const Duration(seconds: 12)),
            repIndex: 2,
          ),
        ],
      )..isFormBad = true;
      final evaluator = _ScriptedTechniqueEvaluator(<bool>[
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      ]);
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(),
        techniqueEvaluator: evaluator,
      );

      RangeRepCoordinatorFrameResult next() {
        final result = _processAcceptedFrame(coordinator, clock, angle: 120);
        clock.advance(const Duration(seconds: 1));
        return result;
      }

      final newlyArmed = next();
      expect(newlyArmed.stateSnapshot.isFormBad, isFalse);
      expect(
        newlyArmed.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.ready,
      );

      final armedViolation = next();
      expect(armedViolation.stateSnapshot.isFormBad, isTrue);
      expect(
        armedViolation.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.keepBodyUpright,
      );

      final armedClean = next();
      expect(armedClean.stateSnapshot.isFormBad, isTrue);
      expect(
        armedClean.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.keepBodyUpright,
      );

      final startedDescending = next();
      expect(startedDescending.stateSnapshot.isFormBad, isTrue);
      expect(
        startedDescending.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.keepBodyUpright,
      );

      final reachedPeak = next();
      expect(reachedPeak.stateSnapshot.isFormBad, isTrue);
      expect(
        reachedPeak.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.keepBodyUpright,
      );

      next();
      final techniqueCompletion = next();
      expect(
        techniqueCompletion.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.repCompleted,
      );
      expect(
        techniqueCompletion
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepSummaryHadFormViolation,
        isTrue,
      );
      expect(
        techniqueCompletion
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        'low confidence',
      );

      next();
      final aborted = next();
      expect(
        aborted.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.repIncomplete,
      );

      next();
      next();
      next();
      final cleanCompletion = next();
      expect(cleanCompletion.stateSnapshot.isFormBad, isFalse);
      expect(
        cleanCompletion.stateSnapshot.feedbackDirective.feedbackCode,
        RangeRepFeedbackCode.repCompleted,
      );
      expect(
        cleanCompletion
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepSummaryHadFormViolation,
        isFalse,
      );
      expect(
        cleanCompletion
            .stateSnapshot
            .calibrationMetrics
            .lastRangeRepValidationStatus,
        'valid',
      );

      expect(engine.isFormBad, isTrue);
      expect(engine.feedbackCode, RangeRepFeedbackCode.awaitNeutral);
      expect(engine.detectionUpdateCount, 13);
      expect(engine.typedUpdateCount, 0);
      expect(engine.legacyUpdateCount, 0);
      expect(evaluator.evaluateCount, 13);
    });

    test('does not evaluate technique for invalid or blocked frames', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = _RecordingRangeRepEngine(config: config, now: clock.now);
      final evaluator = _RecordingTechniqueEvaluator();
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(),
        techniqueEvaluator: evaluator,
      );

      coordinator.processFrame(
        metrics: const ExerciseMetrics.noPose(),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: false,
        qualityAcceptedRangeRepSides: const <RangeRepSide>{},
        preferredRangeRepSide: null,
      );
      coordinator.processFrame(
        metrics: _leftRangeRepMetrics(angle: 170, formMetric: 40),
        now: clock.now(),
        isAcceptedPoseFrame: false,
        didBecomeStableTracking: false,
        qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
        preferredRangeRepSide: RangeRepSide.left,
      );

      expect(evaluator.formMetrics, isEmpty);
      expect(engine.detectionUpdateCount, 0);
      expect(engine.typedUpdateCount, 0);
      expect(engine.legacyUpdateCount, 0);
    });

    test(
      'production completion publishes coordinator score without updating typed engine score state',
      () {
        final clock = _TestClock();
        final config = _squatConfig();
        final engine = RangeRepEngine(config: config, now: clock.now);
        final coordinator = DefaultRangeRepCoordinator(
          engine: engine,
          config: config,
          rangeRepContract: RangeRepContracts.squat,
          rangeRepValidationConfig: const RangeRepValidationConfig(),
        );

        final completedResult = _completeCleanSquatRep(coordinator, clock);
        final interrupted = coordinator.handleLifecycleInterruption();

        expect(completedResult.stateSnapshot.repCount, 1);
        expect(completedResult.stateSnapshot.lastRepScore, greaterThan(0.0));
        expect(
          completedResult.stateSnapshot.calibrationMetrics.hasLastRepBreakdown,
          isTrue,
        );
        expect(engine.lastRepScore, 0.0);
        expect(engine.lastRepScoreBreakdown, isNull);
        expect(
          interrupted.lastRepScore,
          completedResult.stateSnapshot.lastRepScore,
        );
      },
    );

    test(
      'coordinator preserves legacy diagnostics while excluding uncertain tempo from the main score',
      () {
        final config = _squatConfig();
        final legacyClock = _TestClock();
        final legacyEngine = RangeRepEngine(
          config: config,
          now: legacyClock.now,
        );
        _completeLegacySquatRep(legacyEngine, legacyClock);
        final legacyBreakdown = legacyEngine.lastRepScoreBreakdown!;
        final completedRepCoreData = legacyEngine
            .consumeCompletedRepCoreData()!;
        final legacyDiagnostics = legacyEngine.diagnosticsSnapshot;
        final sentinelBreakdown = _sentinelBreakdown();
        final productionClock = _TestClock();
        final productionEngine = _CompletingRangeRepEngine(
          config: config,
          now: productionClock.now,
          completedRepCoreData: completedRepCoreData,
          diagnosticsSnapshot: RangeRepDiagnosticsSnapshot(
            lastRepScoreBreakdown: sentinelBreakdown,
            descendingPhaseAssessment:
                legacyDiagnostics.descendingPhaseAssessment,
            peakPhaseAssessment: legacyDiagnostics.peakPhaseAssessment,
            ascendingPhaseAssessment:
                legacyDiagnostics.ascendingPhaseAssessment,
          ),
        )..lastRepScore = 999.0;
        productionEngine.lastRepScoreBreakdown = sentinelBreakdown;
        final techniqueHistoryTracker = _seedTechniqueHistoryForCompletion(
          config: config,
          completedRepCoreData: completedRepCoreData,
          completionAt: productionClock.now(),
        );
        final coordinator = DefaultRangeRepCoordinator(
          engine: productionEngine,
          config: config,
          rangeRepContract: RangeRepContracts.squat,
          rangeRepValidationConfig: const RangeRepValidationConfig(),
          techniqueHistoryTracker: techniqueHistoryTracker,
        );

        final result = _processAcceptedFrame(
          coordinator,
          productionClock,
          angle: 170,
        );

        _expectTempoSafeScoreProjection(
          result,
          completedRepCoreData: completedRepCoreData,
          expectedBreakdown: legacyBreakdown,
        );
        expect(result.stateSnapshot.lastRepScore, isNot(999.0));
        expect(
          result.stateSnapshot.calibrationMetrics.lastRepRomScore,
          isNot(sentinelBreakdown.romScore),
        );
        expect(productionEngine.consumeCompletedRepCoreDataCalled, isFalse);
        expect(productionEngine.typedUpdateCount, 0);
        expect(productionEngine.detectionUpdateCount, 1);
      },
    );

    test(
      'keeps weighted tempo diagnostics but scores ROM only during quarantine',
      () {
        final result = _scoreCompletedCoreData(
          config: _squatConfig(
            scoreWeights: const RangeRepScoreWeightsConfig(
              descentControlWeight: 2.0,
              ascentControlWeight: 3.0,
            ),
          ),
          completedRepCoreData: _completedRepCoreData(
            descentDuration: const Duration(milliseconds: 1500),
          ),
        );

        expect(result.stateSnapshot.lastRepScore, closeTo(80.0, 0.001));
        expect(
          result.stateSnapshot.calibrationMetrics.lastRepDescentScore,
          100.0,
        );
        expect(
          result.stateSnapshot.calibrationMetrics.lastRepAscentScore,
          90.0,
        );
      },
    );

    test('keeps unknown measurement confidence unknown after scoring', () {
      final result = _scoreCompletedCoreData(
        config: _squatConfig(),
        completedRepCoreData: _completedRepCoreData(),
        includeConfidence: false,
      );

      expect(
        result.stateSnapshot.calibrationMetrics.lastRangeRepSummaryConfidence,
        isNull,
      );
      expect(result.validatedRepEvent?.measurementConfidence, isNull);
    });

    test('preserves the completed-rep form penalty', () {
      final result = _scoreCompletedCoreData(
        config: _squatConfig(),
        completedRepCoreData: _completedRepCoreData(hadFormViolation: true),
        diagnosticsSnapshot: const RangeRepDiagnosticsSnapshot(
          descendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.observed,
          ),
          ascendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.observed,
          ),
        ),
      );

      expect(result.stateSnapshot.lastRepScore, 40.0);
      expect(
        result.stateSnapshot.calibrationMetrics.lastRepHadFormViolation,
        isTrue,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.phaseQualityPenalty,
        isNull,
      );
    });

    test('ignores duration-only phase penalty while tempo is quarantined', () {
      final result = _scoreCompletedCoreData(
        config: _squatConfig(
          phaseQuality: const RangeRepPhaseQualityConfig(
            minDescendingMillis: 1001,
            minAscendingMillis: 1,
          ),
        ),
        completedRepCoreData: _completedRepCoreData(),
      );

      expect(result.stateSnapshot.lastRepScore, 80.0);
      expect(
        result.stateSnapshot.calibrationMetrics.phaseQualityPenalty,
        isNull,
      );
      expect(
        result.stateSnapshot.calibrationMetrics.phaseAdjustedScore,
        isNull,
      );
    });

    test('non-completing frames do not publish engine compatibility score', () {
      final clock = _TestClock();
      final config = _squatConfig();
      final engine = _RecordingRangeRepEngine(config: config, now: clock.now)
        ..lastRepScore = 999.0;
      engine.lastRepScoreBreakdown = _sentinelBreakdown();
      final coordinator = DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: RangeRepContracts.squat,
        rangeRepValidationConfig: const RangeRepValidationConfig(),
      );

      final firstResult = _processAcceptedFrame(coordinator, clock, angle: 170);
      final secondResult = _processAcceptedFrame(
        coordinator,
        clock,
        angle: 140,
      );

      expect(firstResult.stateSnapshot.lastRepScore, 0.0);
      expect(secondResult.stateSnapshot.lastRepScore, 0.0);
      expect(
        secondResult.stateSnapshot.calibrationMetrics.hasLastRepBreakdown,
        isFalse,
      );
    });

    test(
      'lifecycle interruption clears coordinator-owned side state and forces '
      'fresh neutral reacquisition',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        final descendingResult = _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );
        final interrupted = coordinator.handleLifecycleInterruption(
          reason: 'paused',
        );

        expect(descendingResult.stateSnapshot.currentPhase, 'DESCENDING');
        expect(coordinator.diagnosticsState().selectedSideLabel, isNull);
        expect(coordinator.diagnosticsState().hasActiveRepContext, isFalse);
        expect(interrupted.currentPhase, rangeRepAwaitNeutralPhaseLabel);
        final postInterruptionResult = _processAcceptedFrame(
          coordinator,
          clock,
          angle: 90,
        );
        expect(
          postInterruptionResult.stateSnapshot.currentPhase,
          'AWAITING_NEUTRAL',
        );
        expect(postInterruptionResult.stateSnapshot.repCount, 0);
      },
    );

    test(
      'lifecycle neutral reacquisition keeps feedback stable across intermittent invalid frames',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );

        final interrupted = coordinator.handleLifecycleInterruption(
          reason: 'paused',
        );
        expect(
          interrupted.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.awaitNeutral,
        );

        clock.advance(const Duration(milliseconds: 120));
        final firstInvalid = coordinator.processFrame(
          metrics: const ExerciseMetrics.noPose(),
          now: clock.now(),
          isAcceptedPoseFrame: false,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: null,
          preferredRangeRepSide: null,
        );
        expect(
          firstInvalid.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.awaitNeutral,
        );
        expect(
          firstInvalid.stateSnapshot.currentPhase,
          rangeRepAwaitNeutralPhaseLabel,
        );

        clock.advance(const Duration(milliseconds: 120));
        final nonNeutral = _processAcceptedFrame(coordinator, clock, angle: 90);
        expect(
          nonNeutral.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.awaitNeutral,
        );
        expect(
          nonNeutral.stateSnapshot.currentPhase,
          rangeRepAwaitNeutralPhaseLabel,
        );

        clock.advance(const Duration(milliseconds: 120));
        final secondInvalid = coordinator.processFrame(
          metrics: const ExerciseMetrics.noPose(),
          now: clock.now(),
          isAcceptedPoseFrame: false,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: null,
          preferredRangeRepSide: null,
        );
        expect(
          secondInvalid.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.awaitNeutral,
        );
        expect(
          secondInvalid.stateSnapshot.currentPhase,
          rangeRepAwaitNeutralPhaseLabel,
        );

        clock.advance(const Duration(milliseconds: 120));
        final neutral = _driveUntilPhase(
          coordinator,
          clock,
          angle: 170,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );
        expect(
          neutral.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.ready,
        );

        clock.advance(const Duration(milliseconds: 120));
        final visibilityLossAfterNeutral = coordinator.processFrame(
          metrics: const ExerciseMetrics.noPose(),
          now: clock.now(),
          isAcceptedPoseFrame: false,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: null,
          preferredRangeRepSide: null,
        );
        expect(
          visibilityLossAfterNeutral
              .stateSnapshot
              .feedbackDirective
              .feedbackCode,
          RangeRepFeedbackCode.bodyNotVisible,
        );
      },
    );

    test(
      'lifecycle neutral reacquisition still reports sustained visibility loss',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        coordinator.handleLifecycleInterruption(reason: 'paused');

        final firstInvalid = coordinator.processFrame(
          metrics: const ExerciseMetrics.noPose(),
          now: clock.now(),
          isAcceptedPoseFrame: false,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: null,
          preferredRangeRepSide: null,
        );
        expect(
          firstInvalid.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.awaitNeutral,
        );

        clock.advance(rangeRepVisibilityGapGraceDuration);
        final sustainedInvalid = coordinator.processFrame(
          metrics: const ExerciseMetrics.noPose(),
          now: clock.now(),
          isAcceptedPoseFrame: false,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: null,
          preferredRangeRepSide: null,
        );
        expect(
          sustainedInvalid.stateSnapshot.feedbackDirective.feedbackCode,
          RangeRepFeedbackCode.bodyNotVisible,
        );
        expect(sustainedInvalid.stateSnapshot.currentPhase, 'WAITING');
        expect(
          sustainedInvalid.diagnosticsUpdate.visibilityStatus,
          'hard_resync',
        );
      },
    );

    test(
      'lifecycle interruption preserves completed rep facts while clearing only the active context',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );
        _driveUntilPhase(coordinator, clock, angle: 90, expectedPhase: 'PEAK');
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 110,
          expectedPhase: 'ASCENDING',
        );
        final completedResult = _driveUntilPhase(
          coordinator,
          clock,
          angle: 170,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );
        final completedScore = completedResult.stateSnapshot.lastRepScore;
        final completedRom = completedResult.stateSnapshot.lastRepRom;

        _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );

        final interrupted = coordinator.handleLifecycleInterruption(
          reason: 'paused',
        );

        expect(interrupted.repCount, 1);
        expect(interrupted.currentPhase, rangeRepAwaitNeutralPhaseLabel);
        expect(interrupted.lastRepScore, completedScore);
        expect(interrupted.lastRepRom, completedRom);
        expect(
          interrupted.calibrationMetrics.lastRangeRepValidationStatus,
          'valid',
        );
        expect(
          interrupted
              .calibrationMetrics
              .lastRangeRepSummaryCompletedPhaseSequence,
          isTrue,
        );
      },
    );

    test(
      'Front Raise uses the preferred visible side for elbow-form feedback',
      () {
        final clock = _TestClock();
        final coordinator = _buildFrontRaiseCoordinator(clock);

        for (var index = 0; index < 3; index += 1) {
          coordinator.processFrame(
            metrics: _selectedSideMetrics(
              leftAngle: 10,
              rightAngle: 10,
              leftFormMetric: 120,
              rightFormMetric: 175,
            ),
            now: clock.now(),
            isAcceptedPoseFrame: true,
            didBecomeStableTracking: false,
            qualityAcceptedRangeRepSides: const <RangeRepSide>{
              RangeRepSide.left,
              RangeRepSide.right,
            },
            preferredRangeRepSide: RangeRepSide.right,
          );
          clock.advance(const Duration(milliseconds: 120));
        }

        final activeResult = coordinator.processFrame(
          metrics: _selectedSideMetrics(
            leftAngle: 50,
            rightAngle: 50,
            leftFormMetric: 120,
            rightFormMetric: 175,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.left,
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          activeResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'right',
        );
        expect(activeResult.stateSnapshot.isFormBad, isFalse);
        expect(
          activeResult.stateSnapshot.calibrationMetrics.currentBackAngle,
          closeTo(175.0, 0.001),
        );
      },
    );

    test(
      'uses pose-quality preferred side when selected-side coverage is tied',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        final result = coordinator.processFrame(
          metrics: _sideFilteredMetrics(
            leftAngle: 170,
            rightAngle: 168,
            leftAvailable: true,
            rightAvailable: true,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.left,
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          result.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'right',
        );
        expect(result.diagnosticsUpdate.selectedSideLabel, 'right');
        expect(
          result.stateSnapshot.calibrationMetrics.rangeRepSideSelectionReason,
          'selected preferred quality',
        );
      },
    );

    test(
      'automatic unilateral selection follows the leg that starts moving',
      () {
        final clock = _TestClock();
        final coordinator = _buildStandingKneeRaiseCoordinator(clock);

        for (var index = 0; index < 3; index += 1) {
          coordinator.processFrame(
            metrics: _selectedSideMetrics(
              leftAngle: 172,
              rightAngle: 172,
              leftFormMetric: 170,
              rightFormMetric: 170,
            ),
            now: clock.now(),
            isAcceptedPoseFrame: true,
            didBecomeStableTracking: false,
            qualityAcceptedRangeRepSides: const <RangeRepSide>{
              RangeRepSide.left,
              RangeRepSide.right,
            },
            preferredRangeRepSide: RangeRepSide.left,
          );
          clock.advance(const Duration(milliseconds: 120));
        }

        RangeRepCoordinatorFrameResult? result;
        for (var index = 0; index < 3; index += 1) {
          result = coordinator.processFrame(
            metrics: _selectedSideMetrics(
              leftAngle: 172,
              rightAngle: 125,
              leftFormMetric: 170,
              rightFormMetric: 170,
            ),
            now: clock.now(),
            isAcceptedPoseFrame: true,
            didBecomeStableTracking: false,
            qualityAcceptedRangeRepSides: const <RangeRepSide>{
              RangeRepSide.left,
              RangeRepSide.right,
            },
            preferredRangeRepSide: RangeRepSide.left,
          );
          clock.advance(const Duration(milliseconds: 120));
        }

        final metrics = result!.stateSnapshot.calibrationMetrics;
        expect(metrics.selectedRangeRepSide, 'right');
        expect(metrics.rangeRepMovementSelectedSide, 'right');
        expect(metrics.rangeRepAutomaticSideSelectionEnabled, isTrue);
        expect(
          metrics.rangeRepSideSelectionReason,
          anyOf('switched to moving side', 'kept moving side'),
        );
      },
    );

    test(
      'locks the previously selected side while an active rep context is in progress',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 140,
          expectedPhase: 'DESCENDING',
        );

        final lockedResult = coordinator.processFrame(
          metrics: _sideFilteredMetrics(
            leftAngle: 140,
            rightAngle: 95,
            leftAvailable: false,
            rightAvailable: true,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          lockedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'left',
        );
        expect(lockedResult.stateSnapshot.currentPhase, 'WAITING');
        expect(lockedResult.diagnosticsUpdate.selectedSideLabel, 'left');
      },
    );

    test(
      'does not keep the previous side locked while only neutral acquisition is pending',
      () {
        final clock = _TestClock();
        final coordinator = _buildCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 170,
          count: 2,
          spacing: const Duration(milliseconds: 120),
        );

        final switchedResult = coordinator.processFrame(
          metrics: _sideFilteredMetrics(
            leftAngle: 170,
            rightAngle: 95,
            leftAvailable: false,
            rightAvailable: true,
          ),
          now: clock.now(),
          isAcceptedPoseFrame: true,
          didBecomeStableTracking: false,
          qualityAcceptedRangeRepSides: const <RangeRepSide>{
            RangeRepSide.right,
          },
          preferredRangeRepSide: RangeRepSide.right,
        );

        expect(
          switchedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          'right',
        );
        expect(switchedResult.diagnosticsUpdate.selectedSideLabel, 'right');
      },
    );

    test(
      'drives the real sit-up engine/config path through a validated clean rep',
      () {
        final clock = _TestClock();
        final coordinator = _buildSitUpCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 125,
          formMetric: 90,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 108,
          formMetric: 90,
          expectedPhase: 'DESCENDING',
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 68,
          formMetric: 90,
          expectedPhase: 'PEAK',
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 90,
          formMetric: 90,
          expectedPhase: 'PEAK',
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 92,
          formMetric: 90,
          expectedPhase: 'ASCENDING',
        );
        final completedResult = _driveUntilPhase(
          coordinator,
          clock,
          angle: 121,
          formMetric: 90,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        expect(completedResult.stateSnapshot.repCount, 1);
        expect(completedResult.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          completedResult
              .stateSnapshot
              .calibrationMetrics
              .lastRangeRepValidationStatus,
          'valid',
        );
        expect(
          completedResult.stateSnapshot.calibrationMetrics.analysisKind.name,
          'rangeRep',
        );
        expect(
          completedResult
              .stateSnapshot
              .calibrationMetrics
              .lastRangeRepSummaryHadFormViolation,
          isFalse,
        );
      },
    );

    test(
      'sit-up coordinator keeps the base threshold when contract calibration is disabled',
      () {
        final clock = _TestClock();
        final coordinator = _buildSitUpCoordinator(clock);

        _pumpAcceptedFrames(
          coordinator,
          clock,
          angle: 125,
          formMetric: 120,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveUntilPhase(
          coordinator,
          clock,
          angle: 108,
          formMetric: 68.4,
          expectedPhase: 'DESCENDING',
        );
        final peakResult = _driveUntilPhase(
          coordinator,
          clock,
          angle: 52.7,
          formMetric: 68.4,
          expectedPhase: 'PEAK',
        );

        final metrics = peakResult.stateSnapshot.calibrationMetrics;

        expect(peakResult.stateSnapshot.currentPhase, 'PEAK');
        expect(peakResult.stateSnapshot.isFormBad, isFalse);
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

    test('sit-up active rep keeps the previous side lock', () {
      final clock = _TestClock();
      final coordinator = _buildSitUpCoordinator(clock);

      _pumpAcceptedFrames(
        coordinator,
        clock,
        angle: 125,
        formMetric: 90,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      _driveUntilPhase(
        coordinator,
        clock,
        angle: 108,
        formMetric: 90,
        expectedPhase: 'DESCENDING',
      );

      final lockedResult = coordinator.processFrame(
        metrics: _sideFilteredMetrics(
          leftAngle: 108,
          rightAngle: 68,
          leftAvailable: false,
          rightAvailable: true,
          formMetric: 90,
        ),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: false,
        qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.right},
        preferredRangeRepSide: RangeRepSide.right,
      );

      expect(
        lockedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
        'left',
      );
      expect(lockedResult.stateSnapshot.currentPhase, 'WAITING');
      expect(lockedResult.diagnosticsUpdate.selectedSideLabel, 'left');
      expect(lockedResult.diagnosticsUpdate.visibilityStatus, 'brief_freeze');
    });

    test('sit-up brief occlusion recovery resumes the same rep safely', () {
      final clock = _TestClock();
      final coordinator = _buildSitUpCoordinator(clock);

      _pumpAcceptedFrames(
        coordinator,
        clock,
        angle: 125,
        formMetric: 90,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      _driveUntilPhase(
        coordinator,
        clock,
        angle: 108,
        formMetric: 90,
        expectedPhase: 'DESCENDING',
      );

      coordinator.processFrame(
        metrics: _sideFilteredMetrics(
          leftAngle: 108,
          rightAngle: 68,
          leftAvailable: false,
          rightAvailable: true,
          formMetric: 90,
        ),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: false,
        qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.right},
        preferredRangeRepSide: RangeRepSide.right,
      );

      clock.advance(const Duration(milliseconds: 100));
      final recoveredResult = coordinator.processFrame(
        metrics: _leftRangeRepMetrics(angle: 108, formMetric: 90),
        now: clock.now(),
        isAcceptedPoseFrame: true,
        didBecomeStableTracking: true,
        qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
        preferredRangeRepSide: RangeRepSide.left,
      );

      expect(recoveredResult.stateSnapshot.currentPhase, 'DESCENDING');
      expect(
        recoveredResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
        'left',
      );
      expect(
        recoveredResult.diagnosticsUpdate.recordBriefOcclusionRecovery,
        isTrue,
      );
      expect(recoveredResult.diagnosticsUpdate.visibilityStatus, 'stable');
    });

    test(
      'drives the real bilateral biceps curl engine/config path through a validated clean rep',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 162,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 72,
          rightAngle: 74,
          expectedPhase: 'PEAK',
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 98,
          rightAngle: 100,
          expectedPhase: 'ASCENDING',
        );
        final completedResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 158,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        expect(completedResult.stateSnapshot.repCount, 1);
        expect(completedResult.stateSnapshot.currentPhase, 'NEUTRAL');
        expect(
          completedResult.stateSnapshot.calibrationMetrics.selectedRangeRepSide,
          isNull,
        );
        expect(
          completedResult.stateSnapshot.calibrationMetrics.analysisKind.name,
          'rangeRep',
        );
      },
    );

    test(
      'bilateral 84-degree shallow curl returns to neutral without completing a rep',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );

        final shallowResult = _holdAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 84,
          rightAngle: 84,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );
        final recoveredResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        expect(shallowResult.stateSnapshot.currentPhase, 'DESCENDING');
        expect(recoveredResult.stateSnapshot.repCount, 0);
      },
    );

    test(
      'biceps peak gate rejects a deep reported angle when wrists remain shallow',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );

        late RangeRepCoordinatorFrameResult shallowResult;
        for (var index = 0; index < 4; index++) {
          shallowResult = coordinator.processFrame(
            metrics: _bicepsMetricsWithReportedAngle(
              landmarkAngle: 90,
              reportedAngle: 58,
            ),
            now: clock.now(),
            isAcceptedPoseFrame: true,
            didBecomeStableTracking: false,
            qualityAcceptedRangeRepSides: const <RangeRepSide>{
              RangeRepSide.left,
              RangeRepSide.right,
            },
            preferredRangeRepSide: null,
          );
          if (index < 3) {
            clock.advance(const Duration(milliseconds: 90));
          }
        }

        final recoveredResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        expect(shallowResult.stateSnapshot.currentPhase, 'DESCENDING');
        expect(recoveredResult.stateSnapshot.repCount, 0);
      },
    );

    test(
      'a lagging arm around 76 degrees still blocks PEAK at the tightened threshold',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );

        final blockedResult = _holdAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 72,
          rightAngle: 76,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );

        expect(blockedResult.stateSnapshot.currentPhase, 'DESCENDING');
      },
    );

    test(
      'an exact 75-degree bilateral aggregate does not satisfy the strict PEAK entry gate',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );

        final blockedResult = _holdAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 75,
          rightAngle: 75,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );

        expect(blockedResult.stateSnapshot.currentPhase, 'DESCENDING');
      },
    );

    test('severe bilateral lag does not create an early peak', () {
      final clock = _TestClock();
      final coordinator = _buildBicepsCoordinator(clock);

      _pumpAcceptedBicepsFrames(
        coordinator,
        clock,
        leftAngle: 160,
        rightAngle: 160,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      _driveAcceptedBicepsUntilPhase(
        coordinator,
        clock,
        leftAngle: 134,
        rightAngle: 136,
        expectedPhase: 'DESCENDING',
      );
      final laggingResult = _processAcceptedBicepsFrame(
        coordinator,
        clock,
        leftAngle: 72,
        rightAngle: 92,
      );
      final peakResult = _driveAcceptedBicepsUntilPhase(
        coordinator,
        clock,
        leftAngle: 72,
        rightAngle: 74,
        expectedPhase: 'PEAK',
      );

      expect(laggingResult.stateSnapshot.currentPhase, 'DESCENDING');
      expect(peakResult.stateSnapshot.currentPhase, 'PEAK');
    });

    test('one-arm-only curl never completes a bilateral rep', () {
      final clock = _TestClock();
      final coordinator = _buildBicepsCoordinator(clock);

      _pumpAcceptedBicepsFrames(
        coordinator,
        clock,
        leftAngle: 160,
        rightAngle: 160,
        count: 3,
        spacing: const Duration(milliseconds: 120),
      );
      _pumpAcceptedBicepsFrames(
        coordinator,
        clock,
        leftAngle: 72,
        rightAngle: 160,
        count: 4,
        spacing: const Duration(milliseconds: 90),
      );
      final result = _driveAcceptedBicepsUntilPhase(
        coordinator,
        clock,
        leftAngle: 160,
        rightAngle: 160,
        expectedPhase: 'NEUTRAL',
        spacing: const Duration(milliseconds: 120),
      );

      expect(result.stateSnapshot.repCount, 0);
      expect(result.stateSnapshot.currentPhase, 'NEUTRAL');
      expect(result.stateSnapshot.lastRepRom, 0.0);
    });

    test('near-target bilateral ROM completes and keeps a full ROM score', () {
      final clock = _TestClock();
      final coordinator = _buildBicepsCoordinator(clock);
      final completed = _completeAcceptedBicepsRep(
        coordinator,
        clock,
        peakLeftAngle: 72,
        peakRightAngle: 74,
        ascentLeftAngle: 98,
        ascentRightAngle: 100,
      );

      expect(completed.stateSnapshot.repCount, 1);
      expect(completed.stateSnapshot.lastRepRom, closeTo(74.0, 0.001));
      expect(
        completed.stateSnapshot.calibrationMetrics.lastRepRomScore,
        closeTo(100.0, 0.001),
      );
    });

    test(
      'early one-arm neutral return cannot complete the rep and rom stays conservative',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 68,
          rightAngle: 74,
          expectedPhase: 'PEAK',
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 96,
          rightAngle: 100,
          expectedPhase: 'ASCENDING',
        );

        final earlyReturnResult = _processAcceptedBicepsFrame(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 120,
        );
        final completedResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 158,
          expectedPhase: 'NEUTRAL',
          spacing: const Duration(milliseconds: 120),
        );

        expect(earlyReturnResult.stateSnapshot.repCount, 0);
        expect(earlyReturnResult.stateSnapshot.currentPhase, 'ASCENDING');
        expect(completedResult.stateSnapshot.repCount, 1);
        expect(completedResult.stateSnapshot.lastRepRom, closeTo(74.0, 0.001));
      },
    );

    test(
      'peak exit remains blocked until the bilateral aggregate rises above 86 degrees',
      () {
        final clock = _TestClock();
        final coordinator = _buildBicepsCoordinator(clock);

        _pumpAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 160,
          rightAngle: 160,
          count: 3,
          spacing: const Duration(milliseconds: 120),
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 134,
          rightAngle: 136,
          expectedPhase: 'DESCENDING',
        );
        _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 72,
          rightAngle: 74,
          expectedPhase: 'PEAK',
        );

        final blockedExitResult = _holdAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 86,
          rightAngle: 86,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );
        final ascendingResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 88,
          rightAngle: 88,
          expectedPhase: 'ASCENDING',
        );

        expect(blockedExitResult.stateSnapshot.currentPhase, 'PEAK');
        expect(ascendingResult.stateSnapshot.currentPhase, 'ASCENDING');
      },
    );
  });
}

DefaultRangeRepCoordinator _buildCoordinator(_TestClock clock) {
  return _buildCoordinatorWith(
    clock,
    config: _squatConfig(),
    contract: RangeRepContracts.squat,
  );
}

DefaultRangeRepCoordinator _buildSitUpCoordinator(_TestClock clock) {
  return _buildCoordinatorWith(
    clock,
    config: loadExerciseConfig('assets/config/exercises/sit_up.json'),
    contract: RangeRepContracts.sitUp,
  );
}

DefaultRangeRepCoordinator _buildBicepsCoordinator(_TestClock clock) {
  return _buildCoordinatorWith(
    clock,
    config: loadExerciseConfig('assets/config/exercises/biceps_curl.json'),
    contract: RangeRepContracts.bicepsCurl,
  );
}

DefaultRangeRepCoordinator _buildStandingKneeRaiseCoordinator(
  _TestClock clock,
) {
  return _buildCoordinatorWith(
    clock,
    config: loadExerciseConfig(
      'assets/config/exercises/standing_knee_raise.json',
    ),
    contract: RangeRepContracts.standingKneeRaise,
  );
}

DefaultRangeRepCoordinator _buildFrontRaiseCoordinator(_TestClock clock) {
  return _buildCoordinatorWith(
    clock,
    config: loadExerciseConfig('assets/config/exercises/front_raise.json'),
    contract: RangeRepContracts.frontRaise,
  );
}

DefaultRangeRepCoordinator _buildCoordinatorWith(
  _TestClock clock, {
  required ExerciseConfig config,
  required RangeRepContract contract,
}) {
  final engine = const AnalysisEngineFactory().createRangeRep(
    config: config,
    rangeRepContract: contract,
    now: clock.now,
  );

  return DefaultRangeRepCoordinator(
    engine: engine,
    config: config,
    rangeRepContract: contract,
    rangeRepValidationConfig: const RangeRepValidationConfig(),
  );
}

RangeRepCoordinatorFrameResult _completeCleanSquatRep(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock,
) {
  _pumpAcceptedFrames(
    coordinator,
    clock,
    angle: 170,
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  _driveUntilPhase(coordinator, clock, angle: 140, expectedPhase: 'DESCENDING');
  _driveUntilPhase(coordinator, clock, angle: 90, expectedPhase: 'PEAK');
  _driveUntilPhase(coordinator, clock, angle: 110, expectedPhase: 'ASCENDING');
  return _driveUntilPhase(
    coordinator,
    clock,
    angle: 170,
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

RangeRepCoordinatorFrameResult _driveUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  double formMetric = 60.0,
  required String expectedPhase,
  Duration spacing = const Duration(milliseconds: 90),
  int maxFrames = 12,
}) {
  for (var index = 0; index < maxFrames; index++) {
    final result = _processAcceptedFrame(
      coordinator,
      clock,
      angle: angle,
      formMetric: formMetric,
    );
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return result;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  final terminalResult = _processAcceptedFrame(
    coordinator,
    clock,
    angle: angle,
    formMetric: formMetric,
  );
  throw TestFailure(
    'Expected phase $expectedPhase, got '
    '${terminalResult.stateSnapshot.currentPhase}',
  );
}

void _pumpAcceptedFrames(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  double formMetric = 60.0,
  required int count,
  required Duration spacing,
}) {
  for (var index = 0; index < count; index++) {
    _processAcceptedFrame(
      coordinator,
      clock,
      angle: angle,
      formMetric: formMetric,
    );
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

RangeRepCoordinatorFrameResult _processAcceptedFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  double formMetric = 60.0,
  double? sideConfidence = 1.0,
}) {
  return coordinator.processFrame(
    metrics: _leftRangeRepMetrics(
      angle: angle,
      formMetric: formMetric,
      sideConfidence: sideConfidence,
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
  );
}

RangeRepCoordinatorFrameResult _processAcceptedJumpingJackFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double primaryMetric,
  required double formMetric,
}) {
  final leftMetrics = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: primaryMetric,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
  );
  final rightMetrics = RangeRepSideMetrics(
    side: RangeRepSide.right,
    primaryAngle: primaryMetric,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
  );
  final bilateralMetrics = RangeRepBilateralMetrics(
    primaryAngle: primaryMetric,
    formMetric: formMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    leftPrimaryAngle: primaryMetric,
    rightPrimaryAngle: primaryMetric,
    leftFormScore: formMetric,
    rightFormScore: formMetric,
    syncScore: 180,
  );

  return coordinator.processFrame(
    metrics: ExerciseMetrics(
      primaryAngle: primaryMetric,
      formMetric: formMetric,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      hasPose: true,
      landmarks: const <PoseLandmark>[],
      leftRangeRepMetrics: leftMetrics,
      rightRangeRepMetrics: rightMetrics,
      bilateralRangeRepMetrics: bilateralMetrics,
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{
      RangeRepSide.left,
      RangeRepSide.right,
    },
    preferredRangeRepSide: null,
  );
}

RangeRepCoordinatorFrameResult _processAcceptedBicepsFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  double leftUpperArmDriftAngle = 20,
  double rightUpperArmDriftAngle = 20,
}) {
  return coordinator.processFrame(
    metrics: _bicepsMetrics(
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftUpperArmDriftAngle: leftUpperArmDriftAngle,
      rightUpperArmDriftAngle: rightUpperArmDriftAngle,
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{
      RangeRepSide.left,
      RangeRepSide.right,
    },
    preferredRangeRepSide: null,
  );
}

RangeRepCoordinatorFrameResult _driveAcceptedBicepsUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  double leftUpperArmDriftAngle = 20,
  double rightUpperArmDriftAngle = 20,
  required String expectedPhase,
  Duration spacing = const Duration(milliseconds: 90),
  int maxFrames = 12,
}) {
  for (var index = 0; index < maxFrames; index++) {
    final result = _processAcceptedBicepsFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftUpperArmDriftAngle: leftUpperArmDriftAngle,
      rightUpperArmDriftAngle: rightUpperArmDriftAngle,
    );
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return result;
    }
    if (index < maxFrames - 1) {
      clock.advance(spacing);
    }
  }

  final terminalResult = _processAcceptedBicepsFrame(
    coordinator,
    clock,
    leftAngle: leftAngle,
    rightAngle: rightAngle,
    leftUpperArmDriftAngle: leftUpperArmDriftAngle,
    rightUpperArmDriftAngle: rightUpperArmDriftAngle,
  );
  throw TestFailure(
    'Expected phase $expectedPhase, got '
    '${terminalResult.stateSnapshot.currentPhase}',
  );
}

RangeRepCoordinatorFrameResult _holdAcceptedBicepsFrames(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  double leftUpperArmDriftAngle = 20,
  double rightUpperArmDriftAngle = 20,
  required int count,
  required Duration spacing,
}) {
  late RangeRepCoordinatorFrameResult result;

  for (var index = 0; index < count; index++) {
    result = _processAcceptedBicepsFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftUpperArmDriftAngle: leftUpperArmDriftAngle,
      rightUpperArmDriftAngle: rightUpperArmDriftAngle,
    );
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }

  return result;
}

void _pumpAcceptedBicepsFrames(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double leftAngle,
  required double rightAngle,
  double leftUpperArmDriftAngle = 20,
  double rightUpperArmDriftAngle = 20,
  required int count,
  required Duration spacing,
}) {
  for (var index = 0; index < count; index++) {
    _processAcceptedBicepsFrame(
      coordinator,
      clock,
      leftAngle: leftAngle,
      rightAngle: rightAngle,
      leftUpperArmDriftAngle: leftUpperArmDriftAngle,
      rightUpperArmDriftAngle: rightUpperArmDriftAngle,
    );
    if (index < count - 1) {
      clock.advance(spacing);
    }
  }
}

RangeRepCoordinatorFrameResult _completeAcceptedBicepsRep(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double peakLeftAngle,
  required double peakRightAngle,
  required double ascentLeftAngle,
  required double ascentRightAngle,
}) {
  _pumpAcceptedBicepsFrames(
    coordinator,
    clock,
    leftAngle: 160,
    rightAngle: 160,
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  _driveAcceptedBicepsUntilPhase(
    coordinator,
    clock,
    leftAngle: 134,
    rightAngle: 136,
    expectedPhase: 'DESCENDING',
  );
  _driveAcceptedBicepsUntilPhase(
    coordinator,
    clock,
    leftAngle: peakLeftAngle,
    rightAngle: peakRightAngle,
    expectedPhase: 'PEAK',
  );
  _driveAcceptedBicepsUntilPhase(
    coordinator,
    clock,
    leftAngle: ascentLeftAngle,
    rightAngle: ascentRightAngle,
    expectedPhase: 'ASCENDING',
  );

  return _driveAcceptedBicepsUntilPhase(
    coordinator,
    clock,
    leftAngle: 160,
    rightAngle: 158,
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

ExerciseMetrics _leftRangeRepMetrics({
  required double angle,
  required double formMetric,
  double? sideConfidence = 1.0,
}) {
  return _sideFilteredMetrics(
    leftAngle: angle,
    rightAngle: 180.0,
    leftAvailable: true,
    rightAvailable: false,
    formMetric: formMetric,
    sideConfidence: sideConfidence,
  );
}

ExerciseMetrics _bicepsMetrics({
  required double leftAngle,
  required double rightAngle,
  double leftUpperArmDriftAngle = 20,
  double rightUpperArmDriftAngle = 20,
}) {
  const extractor = ExerciseMetricsExtractor();
  return extractor.extract(
    buildBicepsCurlPose(
      leftPrimaryAngle: leftAngle,
      rightPrimaryAngle: rightAngle,
      leftUpperArmDriftAngle: leftUpperArmDriftAngle,
      rightUpperArmDriftAngle: rightUpperArmDriftAngle,
    ),
    loadExerciseConfig('assets/config/exercises/biceps_curl.json'),
    engineKind: EngineKind.rangeRep,
    rangeRepContract: RangeRepContracts.bicepsCurl,
  );
}

ExerciseMetrics _bicepsMetricsWithReportedAngle({
  required double landmarkAngle,
  required double reportedAngle,
}) {
  final metrics = _bicepsMetrics(
    leftAngle: landmarkAngle,
    rightAngle: landmarkAngle,
  );
  final left = metrics.leftRangeRepMetrics;
  final right = metrics.rightRangeRepMetrics;
  final bilateral = metrics.bilateralRangeRepMetrics!;

  return metrics.copyWith(
    primaryAngle: reportedAngle,
    leftRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.left,
      primaryAngle: reportedAngle,
      formMetric: left.formMetric,
      hasPrimaryAngle: left.hasPrimaryAngle,
      hasFormMetric: left.hasFormMetric,
      sideConfidence: left.sideConfidence,
      formSignals: left.formSignals,
    ),
    rightRangeRepMetrics: RangeRepSideMetrics(
      side: RangeRepSide.right,
      primaryAngle: reportedAngle,
      formMetric: right.formMetric,
      hasPrimaryAngle: right.hasPrimaryAngle,
      hasFormMetric: right.hasFormMetric,
      sideConfidence: right.sideConfidence,
      formSignals: right.formSignals,
    ),
    bilateralRangeRepMetrics: RangeRepBilateralMetrics(
      primaryAngle: reportedAngle,
      formMetric: bilateral.formMetric,
      hasPrimaryAngle: bilateral.hasPrimaryAngle,
      hasFormMetric: bilateral.hasFormMetric,
      leftPrimaryAngle: reportedAngle,
      rightPrimaryAngle: reportedAngle,
      leftFormScore: bilateral.leftFormScore,
      rightFormScore: bilateral.rightFormScore,
      syncScore: 180.0,
      formSignals: bilateral.formSignals,
    ),
  );
}

ExerciseMetrics _selectedSideMetrics({
  required double leftAngle,
  required double rightAngle,
  required double leftFormMetric,
  required double rightFormMetric,
}) {
  final leftMetrics = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: leftAngle,
    formMetric: leftFormMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1.0,
  );
  final rightMetrics = RangeRepSideMetrics(
    side: RangeRepSide.right,
    primaryAngle: rightAngle,
    formMetric: rightFormMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1.0,
  );

  return ExerciseMetrics(
    primaryAngle: leftAngle,
    formMetric: leftFormMetric,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: const [],
    leftRangeRepMetrics: leftMetrics,
    rightRangeRepMetrics: rightMetrics,
  );
}

ExerciseMetrics _sideFilteredMetrics({
  required double leftAngle,
  required double rightAngle,
  required bool leftAvailable,
  required bool rightAvailable,
  double formMetric = 60.0,
  double? sideConfidence = 1.0,
}) {
  final leftMetrics = leftAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.left,
          primaryAngle: leftAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: sideConfidence,
        )
      : const RangeRepSideMetrics.unavailable(RangeRepSide.left);
  final rightMetrics = rightAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.right,
          primaryAngle: rightAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: sideConfidence,
        )
      : const RangeRepSideMetrics.unavailable(RangeRepSide.right);

  return ExerciseMetrics(
    primaryAngle: leftAvailable ? leftAngle : rightAngle,
    formMetric: formMetric,
    hasPrimaryAngle: leftAvailable || rightAvailable,
    hasFormMetric: leftAvailable || rightAvailable,
    hasPose: true,
    landmarks: const [],
    leftRangeRepMetrics: leftMetrics,
    rightRangeRepMetrics: rightMetrics,
  );
}

RangeRepCoordinatorFrameResult _scoreCompletedCoreData({
  required ExerciseConfig config,
  required RangeRepCompletedRepCoreData completedRepCoreData,
  RangeRepDiagnosticsSnapshot diagnosticsSnapshot =
      const RangeRepDiagnosticsSnapshot(),
  bool includeConfidence = true,
}) {
  final clock = _TestClock();
  final engine = _CompletingRangeRepEngine(
    config: config,
    now: clock.now,
    completedRepCoreData: completedRepCoreData,
    diagnosticsSnapshot: diagnosticsSnapshot,
  );
  final techniqueHistoryTracker = _seedTechniqueHistoryForCompletion(
    config: config,
    completedRepCoreData: completedRepCoreData,
    completionAt: clock.now(),
  );
  final coordinator = DefaultRangeRepCoordinator(
    engine: engine,
    config: config,
    rangeRepContract: RangeRepContracts.squat,
    rangeRepValidationConfig: const RangeRepValidationConfig(),
    techniqueHistoryTracker: techniqueHistoryTracker,
  );

  return _processAcceptedFrame(
    coordinator,
    clock,
    angle: 170,
    sideConfidence: includeConfidence ? 1.0 : null,
  );
}

LegacyRangeRepTechniqueHistoryTracker _seedTechniqueHistoryForCompletion({
  required ExerciseConfig config,
  required RangeRepCompletedRepCoreData completedRepCoreData,
  required DateTime completionAt,
}) {
  final tracker = LegacyRangeRepTechniqueHistoryTracker(
    phaseQualityConfig: config.rangeRepPhaseQuality,
  );
  final ascentStartedAt = completionAt.subtract(
    completedRepCoreData.ascentDuration,
  );
  final descentStartedAt = ascentStartedAt.subtract(
    completedRepCoreData.descentDuration,
  );
  final worstFormMetric = completedRepCoreData.worstFormMetric;

  tracker.recordFrame(
    engineResult: RangeRepEngineFrameResult(
      wasArmedAtFrameStart: true,
      isArmedAfterUpdate: true,
      repStarted: true,
    ),
    primaryMetric: 170.0,
    formMetric: worstFormMetric,
    hasTechniqueViolation: completedRepCoreData.hadFormViolation,
  );
  tracker.recordFrame(
    engineResult: RangeRepEngineFrameResult(
      wasArmedAtFrameStart: true,
      isArmedAfterUpdate: true,
      confirmedTransition: RangeRepConfirmedTransition(
        type: RangeRepConfirmedTransitionType.startDescending,
        effectiveAt: descentStartedAt,
      ),
      observedRepPhases: const <RangeRepPhase>[RangeRepPhase.descending],
    ),
    primaryMetric: 140.0,
    formMetric: 60.0,
    hasTechniqueViolation: false,
  );
  tracker.recordFrame(
    engineResult: RangeRepEngineFrameResult(
      wasArmedAtFrameStart: true,
      isArmedAfterUpdate: true,
      confirmedTransition: RangeRepConfirmedTransition(
        type: RangeRepConfirmedTransitionType.reachPeak,
        effectiveAt: ascentStartedAt,
      ),
      observedRepPhases: const <RangeRepPhase>[
        RangeRepPhase.descending,
        RangeRepPhase.peak,
      ],
    ),
    primaryMetric: completedRepCoreData.minAngle,
    formMetric: 60.0,
    hasTechniqueViolation: false,
  );
  tracker.recordFrame(
    engineResult: RangeRepEngineFrameResult(
      wasArmedAtFrameStart: true,
      isArmedAfterUpdate: true,
      confirmedTransition: RangeRepConfirmedTransition(
        type: RangeRepConfirmedTransitionType.startAscending,
        effectiveAt: ascentStartedAt,
      ),
      observedRepPhases: const <RangeRepPhase>[
        RangeRepPhase.peak,
        RangeRepPhase.ascending,
      ],
    ),
    primaryMetric: 110.0,
    formMetric: 60.0,
    hasTechniqueViolation: false,
  );

  return tracker;
}

RangeRepCompletedRepCoreData _completedRepCoreData({
  Duration descentDuration = const Duration(milliseconds: 1000),
  Duration ascentDuration = const Duration(milliseconds: 500),
  bool hadFormViolation = false,
}) {
  return RangeRepCompletedRepCoreData(
    repIndex: 1,
    minAngle: 90.0,
    worstFormMetric: hadFormViolation ? 40.0 : 60.0,
    descentDuration: descentDuration,
    ascentDuration: ascentDuration,
    hadFormViolation: hadFormViolation,
    completedPhaseSequence: true,
  );
}

RangeRepEngineFrameResult _scriptedArmedFrame() {
  return RangeRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
  );
}

RangeRepEngineFrameResult _scriptedTransition(
  RangeRepConfirmedTransitionType type,
  DateTime effectiveAt, {
  bool wasArmedAtFrameStart = true,
  bool repStarted = false,
  bool repAborted = false,
  List<RangeRepPhase> phases = const <RangeRepPhase>[],
}) {
  return RangeRepEngineFrameResult(
    wasArmedAtFrameStart: wasArmedAtFrameStart,
    isArmedAfterUpdate: true,
    repStarted: repStarted,
    repAborted: repAborted,
    confirmedTransition: RangeRepConfirmedTransition(
      type: type,
      effectiveAt: effectiveAt,
    ),
    observedRepPhases: phases,
  );
}

RangeRepEngineFrameResult _scriptedCompletion(
  DateTime effectiveAt, {
  required int repIndex,
}) {
  return RangeRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
    completedRepDetectionData: RangeRepCompletedRepDetectionData(
      repIndex: repIndex,
      minAngle: 90,
      descentDuration: const Duration(seconds: 1),
      ascentDuration: const Duration(seconds: 1),
      completedPhaseSequence: true,
    ),
    confirmedTransition: RangeRepConfirmedTransition(
      type: RangeRepConfirmedTransitionType.completeRep,
      effectiveAt: effectiveAt,
    ),
    observedRepPhases: const <RangeRepPhase>[RangeRepPhase.ascending],
  );
}

void _completeLegacySquatRep(RangeRepEngine engine, _TestClock clock) {
  _confirmLegacyTransition(
    engine,
    clock,
    angle: 170,
    confirmationWindow: const Duration(milliseconds: 101),
  );
  _confirmLegacyTransition(engine, clock, angle: 140);
  _confirmLegacyTransition(engine, clock, angle: 90);
  _confirmLegacyTransition(engine, clock, angle: 110);
  _confirmLegacyTransition(
    engine,
    clock,
    angle: 170,
    confirmationWindow: const Duration(milliseconds: 101),
  );
}

void _confirmLegacyTransition(
  RangeRepEngine engine,
  _TestClock clock, {
  required double angle,
  Duration confirmationWindow = const Duration(milliseconds: 81),
}) {
  engine.update(AnalysisFrame(primaryMetric: angle, formMetric: 60));
  clock.advance(confirmationWindow);
  engine.update(AnalysisFrame(primaryMetric: angle, formMetric: 60));
}

void _expectTempoSafeScoreProjection(
  RangeRepCoordinatorFrameResult result, {
  required RangeRepCompletedRepCoreData completedRepCoreData,
  required RepScoreBreakdown expectedBreakdown,
}) {
  final metrics = result.stateSnapshot.calibrationMetrics;

  expect(
    result.stateSnapshot.lastRepScore,
    closeTo(expectedBreakdown.romScore, 0.001),
  );
  expect(
    result.stateSnapshot.lastRepRom,
    closeTo(completedRepCoreData.minAngle, 0.001),
  );
  expect(metrics.hasLastRepBreakdown, isTrue);
  expect(metrics.lastRepRomScore, closeTo(expectedBreakdown.romScore, 0.001));
  expect(
    metrics.lastRepDescentScore,
    closeTo(expectedBreakdown.descentScore, 0.001),
  );
  expect(
    metrics.lastRepAscentScore,
    closeTo(expectedBreakdown.ascentScore, 0.001),
  );
  expect(
    metrics.lastRepWorstBackAngle,
    closeTo(expectedBreakdown.worstBackAngle, 0.001),
  );
  expect(metrics.lastRepHadFormViolation, expectedBreakdown.hadFormViolation);
  expect(metrics.phaseQualityPenalty, isNull);
  expect(metrics.phaseAdjustedScore, isNull);
  expect(metrics.lastRangeRepValidationStatus, 'valid');
  expect(metrics.lastRangeRepValidationReasons, isEmpty);
  expect(
    result.diagnosticsUpdate.completedRepTempoDiagnosticReasons,
    containsAll(<String>[
      RangeRepValidationReason.excessiveDescentSpeed.name,
      RangeRepValidationReason.excessiveAscentSpeed.name,
    ]),
  );
  expect(metrics.lastRangeRepSummaryMinAngle, completedRepCoreData.minAngle);
  expect(
    metrics.lastRangeRepSummaryDescentMillis,
    completedRepCoreData.descentDuration.inMilliseconds,
  );
  expect(
    metrics.lastRangeRepSummaryAscentMillis,
    completedRepCoreData.ascentDuration.inMilliseconds,
  );
}

RepScoreBreakdown _sentinelBreakdown() {
  return const RepScoreBreakdown(
    minAngle: 1.0,
    romScore: 1.0,
    descentSeconds: 1.0,
    descentScore: 1.0,
    ascentSeconds: 1.0,
    ascentScore: 1.0,
    worstBackAngle: 1.0,
    hadFormViolation: false,
    runtimeBaseScore: 1.0,
    finalScore: 1.0,
  );
}

ExerciseConfig _squatConfig({
  RangeRepScoreWeightsConfig? scoreWeights,
  RangeRepPhaseQualityConfig? phaseQuality,
}) {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 150.0,
    thresholdPeak: 95.0,
    formThreshold: 45.0,
    targetMinAngle: 70.0,
    idealDescentSeconds: 1.5,
    idealAscentSeconds: 1.0,
    tempoPenaltyPerSecond: 20.0,
    rangeRepScoreWeights: scoreWeights,
    rangeRepPhaseQuality: phaseQuality,
  );
}

class _CompletingRangeRepEngine extends RangeRepEngine {
  _CompletingRangeRepEngine({
    required super.config,
    required DateTime Function() now,
    required this.completedRepCoreData,
    required RangeRepDiagnosticsSnapshot diagnosticsSnapshot,
  }) : _diagnosticsSnapshot = diagnosticsSnapshot,
       _now = now,
       super(now: now);

  final RangeRepCompletedRepCoreData completedRepCoreData;
  final RangeRepDiagnosticsSnapshot _diagnosticsSnapshot;
  final DateTime Function() _now;
  bool consumeCompletedRepCoreDataCalled = false;
  int detectionUpdateCount = 0;
  int typedUpdateCount = 0;

  @override
  double get lastRepRom => completedRepCoreData.minAngle;

  @override
  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot => _diagnosticsSnapshot;

  @override
  RangeRepDiagnosticsSnapshot get detectionDiagnosticsSnapshot =>
      const RangeRepDiagnosticsSnapshot();

  @override
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
    DateTime? observedAt,
  }) {
    detectionUpdateCount++;
    repCount = completedRepCoreData.repIndex;
    return RangeRepEngineFrameResult(
      wasArmedAtFrameStart: true,
      isArmedAfterUpdate: true,
      completedRepDetectionData: RangeRepCompletedRepDetectionData(
        repIndex: completedRepCoreData.repIndex,
        minAngle: completedRepCoreData.minAngle,
        descentDuration: completedRepCoreData.descentDuration,
        ascentDuration: completedRepCoreData.ascentDuration,
        completedPhaseSequence: completedRepCoreData.completedPhaseSequence,
      ),
      confirmedTransition: RangeRepConfirmedTransition(
        type: RangeRepConfirmedTransitionType.completeRep,
        effectiveAt: _now(),
      ),
      observedRepPhases: const <RangeRepPhase>[RangeRepPhase.ascending],
    );
  }

  @override
  RangeRepEngineFrameResult updateWithTechniqueAssessment(
    AnalysisFrame frame, {
    required RangeRepTechniqueAssessment techniqueAssessment,
  }) {
    typedUpdateCount++;
    throw StateError('Coordinator must use the detection-only API.');
  }

  @override
  RangeRepCompletedRepCoreData? consumeCompletedRepCoreData() {
    consumeCompletedRepCoreDataCalled = true;
    throw StateError('Coordinator must use the typed lifecycle result.');
  }
}

class _RecordingRangeRepEngine extends RangeRepEngine {
  _RecordingRangeRepEngine({
    required super.config,
    required DateTime Function() now,
  }) : super(now: now);

  int legacyUpdateCount = 0;
  int detectionUpdateCount = 0;
  int typedUpdateCount = 0;
  final List<double> primaryMetrics = <double>[];
  final List<DateTime> observationTimes = <DateTime>[];

  @override
  void update(AnalysisFrame frame) {
    legacyUpdateCount++;
  }

  @override
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
    DateTime? observedAt,
  }) {
    detectionUpdateCount++;
    primaryMetrics.add(primaryMetric);
    observationTimes.add(observedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    return RangeRepEngineFrameResult(
      wasArmedAtFrameStart: false,
      isArmedAfterUpdate: false,
    );
  }

  @override
  RangeRepEngineFrameResult updateWithTechniqueAssessment(
    AnalysisFrame frame, {
    required RangeRepTechniqueAssessment techniqueAssessment,
  }) {
    typedUpdateCount++;
    throw StateError('Coordinator must use the detection-only API.');
  }
}

class _ScriptedRangeRepEngine extends RangeRepEngine {
  _ScriptedRangeRepEngine({
    required super.config,
    super.primaryMetricDirection,
    required DateTime Function() now,
    required List<RangeRepEngineFrameResult> results,
  }) : _results = List<RangeRepEngineFrameResult>.of(results),
       super(now: now);

  final List<RangeRepEngineFrameResult> _results;
  int detectionUpdateCount = 0;
  int typedUpdateCount = 0;
  int legacyUpdateCount = 0;

  @override
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
    DateTime? observedAt,
  }) {
    detectionUpdateCount++;
    final result = _results.removeAt(0);
    final detectionData = result.completedRepDetectionData;
    if (detectionData != null) {
      repCount = detectionData.repIndex;
    }
    return result;
  }

  @override
  RangeRepEngineFrameResult updateWithTechniqueAssessment(
    AnalysisFrame frame, {
    required RangeRepTechniqueAssessment techniqueAssessment,
  }) {
    typedUpdateCount++;
    throw StateError('Coordinator must use the detection-only API.');
  }

  @override
  void update(AnalysisFrame frame) {
    legacyUpdateCount++;
  }
}

class _ScriptedTechniqueEvaluator extends LegacyRangeRepTechniqueEvaluator {
  _ScriptedTechniqueEvaluator(List<bool> violations)
    : _violations = List<bool>.of(violations);

  final List<bool> _violations;
  int evaluateCount = 0;

  @override
  RangeRepTechniqueAssessment evaluate({
    required double formMetric,
    required double formThreshold,
  }) {
    evaluateCount++;
    if (!_violations.removeAt(0)) {
      return RangeRepTechniqueAssessment.empty;
    }
    return RangeRepTechniqueAssessment(
      observations: const <RangeRepTechniqueObservation>[
        RangeRepTechniqueObservation(
          type: RangeRepTechniqueObservationType.legacyFormThresholdViolation,
          code: 'legacy_form_threshold_violation',
          severity: RangeRepTechniqueSeverity.warning,
        ),
      ],
    );
  }
}

class _RecordingTechniqueEvaluator extends LegacyRangeRepTechniqueEvaluator {
  final List<double> formMetrics = <double>[];
  final List<RangeRepTechniqueAssessment> assessments =
      <RangeRepTechniqueAssessment>[];

  @override
  RangeRepTechniqueAssessment evaluate({
    required double formMetric,
    required double formThreshold,
  }) {
    formMetrics.add(formMetric);
    final assessment = super.evaluate(
      formMetric: formMetric,
      formThreshold: formThreshold,
    );
    assessments.add(assessment);
    return assessment;
  }
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
