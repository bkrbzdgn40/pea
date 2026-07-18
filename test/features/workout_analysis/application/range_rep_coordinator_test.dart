import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_outcome_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
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
      'both arms around 84 degrees can reach PEAK through the real bilateral path',
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

        final peakResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 84,
          rightAngle: 84,
          expectedPhase: 'PEAK',
        );

        expect(peakResult.stateSnapshot.currentPhase, 'PEAK');
      },
    );

    test(
      'a lagging arm around 86 degrees still blocks PEAK at the relaxed threshold',
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
          leftAngle: 84,
          rightAngle: 86,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );

        expect(blockedResult.stateSnapshot.currentPhase, 'DESCENDING');
      },
    );

    test(
      'an exact 85-degree bilateral aggregate does not satisfy the strict PEAK entry gate',
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
          leftAngle: 85,
          rightAngle: 85,
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
      expect(result.stateSnapshot.lastRepRom, 180.0);
    });

    test(
      'valid-but-not-ideal bilateral ROM is accepted while ideal depth keeps a better ROM score',
      () {
        final shallowClock = _TestClock();
        final shallowCoordinator = _buildBicepsCoordinator(shallowClock);
        final shallowCompleted = _completeAcceptedBicepsRep(
          shallowCoordinator,
          shallowClock,
          peakLeftAngle: 84,
          peakRightAngle: 84,
          ascentLeftAngle: 98,
          ascentRightAngle: 98,
        );

        final idealClock = _TestClock();
        final idealCoordinator = _buildBicepsCoordinator(idealClock);
        final idealCompleted = _completeAcceptedBicepsRep(
          idealCoordinator,
          idealClock,
          peakLeftAngle: 72,
          peakRightAngle: 74,
          ascentLeftAngle: 98,
          ascentRightAngle: 100,
        );

        expect(shallowCompleted.stateSnapshot.repCount, 1);
        expect(shallowCompleted.stateSnapshot.lastRepRom, closeTo(84.0, 0.001));
        expect(
          shallowCompleted.stateSnapshot.calibrationMetrics.lastRepRomScore,
          closeTo(91.0, 0.001),
        );
        expect(idealCompleted.stateSnapshot.repCount, 1);
        expect(idealCompleted.stateSnapshot.lastRepRom, closeTo(74.0, 0.001));
        expect(
          idealCompleted.stateSnapshot.calibrationMetrics.lastRepRomScore,
          closeTo(100.0, 0.001),
        );
        expect(
          shallowCompleted.stateSnapshot.calibrationMetrics.lastRepRomScore,
          lessThan(
            idealCompleted.stateSnapshot.calibrationMetrics.lastRepRomScore,
          ),
        );
      },
    );

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
          rightAngle: 76,
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
        expect(completedResult.stateSnapshot.lastRepRom, closeTo(76.0, 0.001));
      },
    );

    test(
      'peak exit remains blocked until the bilateral aggregate rises above 96 degrees',
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
          leftAngle: 84,
          rightAngle: 84,
          expectedPhase: 'PEAK',
        );

        final blockedExitResult = _holdAcceptedBicepsFrames(
          coordinator,
          clock,
          leftAngle: 96,
          rightAngle: 96,
          count: 4,
          spacing: const Duration(milliseconds: 90),
        );
        final ascendingResult = _driveAcceptedBicepsUntilPhase(
          coordinator,
          clock,
          leftAngle: 98,
          rightAngle: 98,
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
}) {
  return coordinator.processFrame(
    metrics: _leftRangeRepMetrics(angle: angle, formMetric: formMetric),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
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
}) {
  return _sideFilteredMetrics(
    leftAngle: angle,
    rightAngle: 180.0,
    leftAvailable: true,
    rightAvailable: false,
    formMetric: formMetric,
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

ExerciseMetrics _sideFilteredMetrics({
  required double leftAngle,
  required double rightAngle,
  required bool leftAvailable,
  required bool rightAvailable,
  double formMetric = 60.0,
}) {
  final leftMetrics = leftAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.left,
          primaryAngle: leftAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 1.0,
        )
      : const RangeRepSideMetrics.unavailable(RangeRepSide.left);
  final rightMetrics = rightAvailable
      ? RangeRepSideMetrics(
          side: RangeRepSide.right,
          primaryAngle: rightAngle,
          formMetric: formMetric,
          hasPrimaryAngle: true,
          hasFormMetric: true,
          sideConfidence: 1.0,
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

ExerciseConfig _squatConfig() {
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
  );
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
