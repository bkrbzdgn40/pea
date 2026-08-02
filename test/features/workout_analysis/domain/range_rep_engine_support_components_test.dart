import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_legacy_score_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_phase_quality_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_lifecycle.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_visibility_lifecycle.dart';

void main() {
  group('RangeRepLegacyScoreTracker', () {
    test('preserves the legacy score and reset contract', () {
      final tracker = RangeRepLegacyScoreTracker(
        config: _config(),
        primaryMetricDirection: RangeRepPrimaryMetricDirection.decreasingToPeak,
      );

      tracker.calculate(
        completedRepCoreData: const RangeRepCompletedRepCoreData(
          repIndex: 1,
          minAngle: 70,
          worstFormMetric: 90,
          descentDuration: Duration(seconds: 2),
          ascentDuration: Duration(seconds: 1),
          hadFormViolation: false,
          completedPhaseSequence: true,
          startAngle: 170,
          primaryRom: 100,
        ),
        descendingPhaseAssessment: const RangeRepPhaseQualityAssessment(
          status: RangeRepPhaseQualityStatus.observed,
        ),
        ascendingPhaseAssessment: const RangeRepPhaseQualityAssessment(
          status: RangeRepPhaseQualityStatus.observed,
        ),
      );

      expect(tracker.lastRepScore, 100);
      expect(tracker.lastRepScoreBreakdown?.finalScore, 100);
      expect(tracker.lastRepScoreBreakdown?.phaseQualityPenalty, isNull);

      tracker.reset();

      expect(tracker.lastRepScore, 0);
      expect(tracker.lastRepScoreBreakdown, isNull);
    });
  });

  group('RangeRepPhaseQualityTracker', () {
    test('owns phase samples and completed telemetry independently', () {
      final tracker = RangeRepPhaseQualityTracker(config: _config());
      final startedAt = DateTime.utc(2030, 1, 1);

      tracker.start(
        phase: RangeRepPhase.descending,
        startedAt: startedAt,
        primaryMetric: 150,
        formMetric: 80,
        hadFormViolation: false,
      );
      tracker.record(
        phase: RangeRepPhase.descending,
        primaryMetric: 120,
        formMetric: 40,
        hadFormViolation: true,
      );
      tracker.complete(
        phase: RangeRepPhase.descending,
        endedAt: startedAt.add(const Duration(milliseconds: 300)),
      );

      final telemetry = tracker.completedTelemetry(
        startedAt.add(const Duration(milliseconds: 300)),
      );
      final assessment = tracker.assess(
        phase: RangeRepPhase.descending,
        phaseQuality: telemetry.descendingPhaseQuality,
        isActivePhase: false,
      );

      expect(telemetry.descendingPhaseQuality.durationMs, 300);
      expect(telemetry.descendingPhaseQuality.minPrimaryMetric, 120);
      expect(telemetry.descendingPhaseQuality.worstFormMetric, 40);
      expect(assessment.status, RangeRepPhaseQualityStatus.flagged);
      expect(
        assessment.issues,
        containsAll(<RangeRepPhaseQualityIssue>[
          RangeRepPhaseQualityIssue.durationTooShort,
          RangeRepPhaseQualityIssue.formViolation,
        ]),
      );

      tracker.captureCompleted(startedAt);
      tracker.reset();
      expect(tracker.lastCompletedTelemetry, isNotNull);

      tracker.resetAll();
      expect(tracker.lastCompletedTelemetry, isNull);
    });
  });

  group('RangeRepTimingLifecycle', () {
    test('records one cycle and owns rejection counters', () {
      final lifecycle = RangeRepTimingLifecycle();
      final base = DateTime.utc(2030, 1, 1);

      lifecycle.recordAcceptedFrame(
        result: GenericRepEngineFrameResult(
          wasArmedAtFrameStart: false,
          isArmedAfterUpdate: true,
          phaseBeforeUpdate: GenericRepPhase.neutral,
          phaseAfterUpdate: GenericRepPhase.towardPeak,
          repStarted: true,
          observedAt: base,
        ),
        primaryMetric: 140,
        observedAt: base,
        processedAt: base.add(const Duration(milliseconds: 20)),
      );
      lifecycle.markVisibilityGap();
      lifecycle.recordRejectedObservation();

      final completion = lifecycle.finishCompleted(null);

      expect(completion.trace?.sampleCount, 1);
      expect(completion.trace?.towardPeakSampleCount, 1);
      expect(completion.trace?.hadVisibilityGap, isTrue);
      expect(lifecycle.nonMonotonicObservationCount, 1);
      expect(lifecycle.activeSnapshot, isNull);
      expect(lifecycle.lastEndedSnapshot, same(completion.trace));
      expect(lifecycle.lastAssessment, same(completion.assessment));

      lifecycle.reset();
      expect(lifecycle.nonMonotonicObservationCount, 0);
      expect(lifecycle.lastEndedSnapshot, isNull);
      expect(lifecycle.lastAssessment, isNull);
    });
  });

  group('RangeRepVisibilityLifecycle', () {
    test('applies only compatible visibility gaps', () {
      var now = DateTime.utc(2030, 1, 1);
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 140,
          peakThreshold: 90,
        ),
        now: () => now,
      );
      final lifecycle = RangeRepVisibilityLifecycle(
        graceDuration: const Duration(milliseconds: 1500),
        now: () => now,
      );
      var startedCount = 0;
      Duration? appliedGap;

      lifecycle.begin(engine: engine, onGapStarted: () => startedCount++);
      now = now.add(const Duration(milliseconds: 120));
      final compatible = lifecycle.resume(
        engine: engine,
        primaryMetric: 170,
        onCompatibleGap: (gap) => appliedGap = gap,
      );

      expect(startedCount, 1);
      expect(compatible.disposition, VisibilityGapResumeDisposition.compatible);
      expect(appliedGap, const Duration(milliseconds: 120));

      lifecycle.begin(engine: engine, onGapStarted: () => startedCount++);
      final incompatible = lifecycle.resume(
        engine: engine,
        primaryMetric: 100,
        onCompatibleGap: (_) => fail('incompatible gap must not be applied'),
      );

      expect(startedCount, 2);
      expect(
        incompatible.disposition,
        VisibilityGapResumeDisposition.incompatible,
      );
      expect(
        lifecycle
            .resume(engine: engine, primaryMetric: 170, onCompatibleGap: (_) {})
            .disposition,
        VisibilityGapResumeDisposition.noGap,
      );
    });
  });
}

ExerciseConfig _config() {
  return ExerciseConfig(
    name: 'test',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 140,
    thresholdPeak: 90,
    idealDescentSeconds: 2,
    idealAscentSeconds: 1,
    formThreshold: 45,
    targetMinAngle: 70,
    tempoPenaltyPerSecond: 20,
    rangeRepPhaseQuality: const RangeRepPhaseQualityConfig(
      minDescendingMillis: 500,
      minAscendingMillis: 400,
    ),
  );
}
