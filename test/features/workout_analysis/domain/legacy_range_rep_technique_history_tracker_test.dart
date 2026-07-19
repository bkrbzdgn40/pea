import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_phase_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_technique_history_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_completed_rep_detection_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_confirmed_transition.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

void main() {
  group('LegacyRangeRepTechniqueHistoryTracker', () {
    test('tracks sticky rep history and exact dual-phase attribution', () {
      final tracker = LegacyRangeRepTechniqueHistoryTracker(
        phaseQualityConfig: const RangeRepPhaseQualityConfig(
          minDescendingMillis: 300,
          minAscendingMillis: 300,
        ),
      );
      final startedAt = DateTime(2026, 1, 1, 12);

      _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.startDescending,
          effectiveAt: startedAt,
          repStarted: true,
          phases: const <RangeRepPhase>[RangeRepPhase.descending],
        ),
        primaryMetric: 140,
        formMetric: 70,
      );
      _record(
        tracker,
        result: _phaseResult(RangeRepPhase.descending),
        primaryMetric: 130,
        formMetric: 50,
        hasTechniqueViolation: true,
      );

      final peakAt = startedAt.add(const Duration(milliseconds: 300));
      _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.reachPeak,
          effectiveAt: peakAt,
          phases: const <RangeRepPhase>[
            RangeRepPhase.descending,
            RangeRepPhase.peak,
          ],
        ),
        primaryMetric: 90,
        formMetric: 45,
      );
      var snapshot = tracker.snapshot(
        now: peakAt,
        preferLastCompletedTelemetry: false,
      );

      expect(snapshot.currentRepWorstFormMetric, 45);
      expect(snapshot.currentRepHadFormViolation, isTrue);
      expect(
        snapshot.phaseQualityTelemetry.descendingPhaseQuality.durationMs,
        300,
      );
      expect(
        snapshot.phaseQualityTelemetry.descendingPhaseQuality.minPrimaryMetric,
        90,
      );
      expect(
        snapshot.phaseQualityTelemetry.peakPhaseQuality.minPrimaryMetric,
        90,
      );
      expect(
        snapshot.phaseQualityTelemetry.peakPhaseQuality.worstFormMetric,
        45,
      );

      final ascentAt = peakAt.add(const Duration(milliseconds: 200));
      _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.startAscending,
          effectiveAt: ascentAt,
          phases: const <RangeRepPhase>[
            RangeRepPhase.peak,
            RangeRepPhase.ascending,
          ],
        ),
        primaryMetric: 110,
        formMetric: 40,
      );
      snapshot = tracker.snapshot(
        now: ascentAt,
        preferLastCompletedTelemetry: false,
      );

      expect(snapshot.currentRepWorstFormMetric, 40);
      expect(snapshot.phaseQualityTelemetry.peakPhaseQuality.durationMs, 200);
      expect(
        snapshot.phaseQualityTelemetry.peakPhaseQuality.worstFormMetric,
        40,
      );
      expect(
        snapshot.phaseQualityTelemetry.ascendingPhaseQuality.worstFormMetric,
        40,
      );

      final completedAt = ascentAt.add(const Duration(milliseconds: 300));
      final completedTechnique = _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.completeRep,
          effectiveAt: completedAt,
          phases: const <RangeRepPhase>[RangeRepPhase.ascending],
          detectionData: const RangeRepCompletedRepDetectionData(
            repIndex: 1,
            minAngle: 90,
            descentDuration: Duration(milliseconds: 300),
            ascentDuration: Duration(milliseconds: 300),
            completedPhaseSequence: true,
          ),
        ),
        primaryMetric: 170,
        formMetric: 55,
      );
      snapshot = tracker.snapshot(
        now: completedAt,
        preferLastCompletedTelemetry: true,
      );

      expect(completedTechnique?.worstFormMetric, 40);
      expect(completedTechnique?.hadFormViolation, isTrue);
      expect(
        snapshot.phaseQualityTelemetry.descendingPhaseQuality.durationMs,
        300,
      );
      expect(snapshot.phaseQualityTelemetry.peakPhaseQuality.durationMs, 200);
      expect(
        snapshot.phaseQualityTelemetry.ascendingPhaseQuality.durationMs,
        300,
      );
      expect(
        snapshot.descendingPhaseAssessment.status,
        RangeRepPhaseQualityStatus.flagged,
      );
      expect(
        snapshot.descendingPhaseAssessment.issues,
        contains(RangeRepPhaseQualityIssue.formViolation),
      );
      expect(
        snapshot.peakPhaseAssessment.status,
        RangeRepPhaseQualityStatus.observed,
      );
      expect(
        snapshot.ascendingPhaseAssessment.status,
        RangeRepPhaseQualityStatus.observed,
      );
      expect(
        snapshot.phaseFeedbackCandidate,
        RangeRepFeedbackCode.maintainForm,
      );
    });

    test(
      'abort clears active history without replacing completed telemetry',
      () {
        final tracker = LegacyRangeRepTechniqueHistoryTracker(
          phaseQualityConfig: null,
        );
        final startedAt = DateTime(2026, 1, 1, 12);

        _record(
          tracker,
          result: _transitionResult(
            type: RangeRepConfirmedTransitionType.startDescending,
            effectiveAt: startedAt,
            repStarted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          primaryMetric: 140,
          formMetric: 50,
          hasTechniqueViolation: true,
        );
        final abortedTechnique = _record(
          tracker,
          result: _transitionResult(
            type: RangeRepConfirmedTransitionType.abortToNeutral,
            effectiveAt: startedAt.add(const Duration(milliseconds: 250)),
            repAborted: true,
            phases: const <RangeRepPhase>[RangeRepPhase.descending],
          ),
          primaryMetric: 170,
          formMetric: 40,
          hasTechniqueViolation: true,
        );
        final snapshot = tracker.snapshot(
          now: startedAt.add(const Duration(milliseconds: 250)),
          preferLastCompletedTelemetry: false,
        );

        expect(abortedTechnique, isNull);
        expect(snapshot.currentRepWorstFormMetric, 180);
        expect(snapshot.currentRepHadFormViolation, isFalse);
        expect(
          snapshot.phaseQualityTelemetry.descendingPhaseQuality.hasData,
          isFalse,
        );
        expect(
          snapshot.descendingPhaseAssessment.status,
          RangeRepPhaseQualityStatus.unavailable,
        );
      },
    );

    test('excludes the exact applied visibility-gap duration', () {
      final tracker = LegacyRangeRepTechniqueHistoryTracker(
        phaseQualityConfig: null,
      );
      final startedAt = DateTime(2026, 1, 1, 12);

      _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.startDescending,
          effectiveAt: startedAt,
          repStarted: true,
          phases: const <RangeRepPhase>[RangeRepPhase.descending],
        ),
        primaryMetric: 140,
        formMetric: 60,
      );
      tracker.shiftActivePhaseTiming(const Duration(milliseconds: 1000));
      final peakAt = startedAt.add(const Duration(milliseconds: 1300));
      _record(
        tracker,
        result: _transitionResult(
          type: RangeRepConfirmedTransitionType.reachPeak,
          effectiveAt: peakAt,
          phases: const <RangeRepPhase>[
            RangeRepPhase.descending,
            RangeRepPhase.peak,
          ],
        ),
        primaryMetric: 90,
        formMetric: 60,
      );

      final snapshot = tracker.snapshot(
        now: peakAt,
        preferLastCompletedTelemetry: false,
      );
      expect(
        snapshot.phaseQualityTelemetry.descendingPhaseQuality.durationMs,
        300,
      );
    });
  });

  group('LegacyRangeRepPhaseQualityPolicy', () {
    const policy = LegacyRangeRepPhaseQualityPolicy();

    test('preserves assessment rules and issue order', () {
      const phaseQuality = RangeRepPhaseQualitySnapshot(
        hasData: true,
        durationMs: 199,
        hadFormViolation: true,
      );
      final assessment = policy.assess(
        phase: RangeRepPhase.descending,
        phaseQuality: phaseQuality,
        isActivePhase: false,
        config: const RangeRepPhaseQualityConfig(minDescendingMillis: 200),
      );

      expect(assessment.status, RangeRepPhaseQualityStatus.flagged);
      expect(assessment.issues, const <RangeRepPhaseQualityIssue>[
        RangeRepPhaseQualityIssue.durationTooShort,
        RangeRepPhaseQualityIssue.formViolation,
      ]);
      expect(
        policy
            .assess(
              phase: RangeRepPhase.peak,
              phaseQuality: const RangeRepPhaseQualitySnapshot(),
              isActivePhase: false,
              config: null,
            )
            .status,
        RangeRepPhaseQualityStatus.unavailable,
      );
    });

    test('preserves phase feedback precedence', () {
      const duration = RangeRepPhaseQualityAssessment(
        status: RangeRepPhaseQualityStatus.flagged,
        issues: <RangeRepPhaseQualityIssue>[
          RangeRepPhaseQualityIssue.durationTooShort,
        ],
      );
      const form = RangeRepPhaseQualityAssessment(
        status: RangeRepPhaseQualityStatus.flagged,
        issues: <RangeRepPhaseQualityIssue>[
          RangeRepPhaseQualityIssue.formViolation,
        ],
      );
      const observed = RangeRepPhaseQualityAssessment(
        status: RangeRepPhaseQualityStatus.observed,
      );

      expect(
        policy.feedbackCandidate(
          descending: duration,
          peak: form,
          ascending: duration,
        ),
        RangeRepFeedbackCode.controlDescent,
      );
      expect(
        policy.feedbackCandidate(
          descending: observed,
          peak: form,
          ascending: duration,
        ),
        RangeRepFeedbackCode.controlAscent,
      );
      expect(
        policy.feedbackCandidate(
          descending: form,
          peak: form,
          ascending: observed,
        ),
        RangeRepFeedbackCode.stabilizeTransition,
      );
      expect(
        policy.feedbackCandidate(
          descending: form,
          peak: observed,
          ascending: observed,
        ),
        RangeRepFeedbackCode.maintainForm,
      );
      expect(
        policy.feedbackCandidate(
          descending: observed,
          peak: observed,
          ascending: observed,
        ),
        isNull,
      );
    });
  });
}

LegacyRangeRepCompletedTechniqueData? _record(
  LegacyRangeRepTechniqueHistoryTracker tracker, {
  required RangeRepEngineFrameResult result,
  required double primaryMetric,
  required double formMetric,
  bool hasTechniqueViolation = false,
}) {
  return tracker.recordFrame(
    engineResult: result,
    primaryMetric: primaryMetric,
    formMetric: formMetric,
    hasTechniqueViolation: hasTechniqueViolation,
  );
}

RangeRepEngineFrameResult _phaseResult(RangeRepPhase phase) {
  return RangeRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
    observedRepPhases: <RangeRepPhase>[phase],
  );
}

RangeRepEngineFrameResult _transitionResult({
  required RangeRepConfirmedTransitionType type,
  required DateTime effectiveAt,
  required List<RangeRepPhase> phases,
  bool repStarted = false,
  bool repAborted = false,
  RangeRepCompletedRepDetectionData? detectionData,
}) {
  return RangeRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
    repStarted: repStarted,
    repAborted: repAborted,
    completedRepDetectionData: detectionData,
    confirmedTransition: RangeRepConfirmedTransition(
      type: type,
      effectiveAt: effectiveAt,
    ),
    observedRepPhases: phases,
  );
}
