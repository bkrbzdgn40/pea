import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_frame_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_calibration_metrics_builder.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_validity.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_score_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_calibration_baseline.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

void main() {
  const builder = WorkoutCalibrationMetricsBuilder();

  test(
    'buildRangeRep preserves range-rep telemetry in the range-rep payload',
    () {
      final metrics = builder.buildRangeRep(
        currentFormMetric: 170,
        thresholdValue: 150,
        diagnostics: const RangeRepDiagnosticsSnapshot(
          currentRepWorstBackAngle: 155,
          currentRepHadFormViolation: true,
          phaseGateStatus: 'armed',
          hasPendingTransition: true,
          pendingTransitionLabel: 'descending',
          lastConfirmedTransitionLabel: 'neutral',
          descendingPhaseQuality: RangeRepPhaseQualitySnapshot(
            hasData: true,
            durationMs: 420,
            worstFormMetric: 148,
            hadFormViolation: true,
          ),
          descendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.flagged,
            issues: <RangeRepPhaseQualityIssue>[
              RangeRepPhaseQualityIssue.formViolation,
            ],
          ),
          phaseFeedbackCandidate: 'stabilize',
        ),
        lastBreakdown: const RepScoreBreakdown(
          minAngle: 88,
          romScore: 81,
          descentSeconds: 1.2,
          descentScore: 79,
          ascentSeconds: 1.1,
          ascentScore: 83,
          worstBackAngle: 150,
          hadFormViolation: true,
          runtimeBaseScore: 84,
          finalScore: 80,
          phaseQualityPenalty: 4,
          phaseAdjustedScore: 80,
        ),
        lastValidationResult: RangeRepValidationResult.invalid(
          const <RangeRepValidationReason>[
            RangeRepValidationReason.persistentFormBreak,
          ],
        ),
        lastSummaryCandidate: const RangeRepRepSummary(
          repIndex: 1,
          minAngle: 88,
          worstFormMetric: 150,
          descentDuration: Duration(milliseconds: 700),
          ascentDuration: Duration(milliseconds: 650),
          hadFormViolation: true,
          hadCoverageDrop: false,
          switchedSideDuringRep: false,
          completedPhaseSequence: true,
          selectedSideLabel: 'left',
        ),
        rangeRepSideHysteresisStatus: 'locked',
        rangeRepSideConsistencyStatus: 'stable',
        calibrationSnapshot: null,
        calibrationThresholdDecisionCount: 4,
        calibrationThresholdAppliedCount: 3,
        calibrationThresholdNoBaselineCount: 1,
        calibrationThresholdInsufficientSamplesCount: 2,
        calibrationThresholdMissingFormBaselineCount: 0,
        calibrationThresholdSideMismatchCount: 1,
        calibrationThresholdOffsetTooSmallCount: 0,
        sessionCalibrationBaselineCandidate: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
        ),
        lastRangeRepValidatedRepIndex: 1,
        rangeRepValidatedCount: 1,
        rangeRepLowConfidenceCount: 2,
        rangeRepInvalidCount: 3,
        baseFormThreshold: 45,
        effectiveFormThreshold: 42,
        calibrationThresholdOffsetCandidate: -3,
        calibrationThresholdOffsetApplied: true,
        calibrationThresholdOffsetFallbackReason: 'baseline',
        calibrationThresholdOffsetSampleCount: 3,
        calibrationThresholdOffsetBaselineSideLabel: 'left',
        isRangeRepFrameValid: false,
        hasPrimaryAngle: true,
        hasFormMetric: true,
        rangeRepInvalidReason: RangeRepFrameInvalidReason.missingFormMetric,
        selectedRangeRepSide: 'left',
        rangeRepSideSelectionReason: 'locked active side',
        rangeRepAutomaticSideSelectionEnabled: true,
        rangeRepMovementSelectedSide: 'left',
        leftRangeRepCoverage: 7,
        rightRangeRepCoverage: 1,
        leftRangeRepSideConfidence: 0.9,
        rightRangeRepSideConfidence: 0.1,
        rangeRepInvalidFrameStreak: 2,
        rangeRepInvalidDurationMs: 300,
        rangeRepResyncTriggered: true,
        rangeRepResyncReason: 'brief occlusion',
        rangeRepVisibilityStatus: 'brief_freeze',
        currentBodyLineAngle: 170,
        currentArmSupportAngle: 90,
        currentLegExtensionAngle: 175,
        currentTorsoAngle: 160,
        currentDepthMetric: 88,
        currentAlignmentMetric: 172,
        currentStabilityMetric: 168,
        currentLockoutMetric: 176,
        currentBottomControlMetric: 92,
        hasBodyLineAngle: true,
        hasArmSupportAngle: true,
        hasLegExtensionAngle: true,
      );

      expect(metrics.analysisKind.name, 'rangeRep');
      expect(metrics.rangeRep, isNotNull);
      expect(metrics.hold, isNull);
      expect(metrics.currentBackAngle, 170);
      expect(metrics.formThreshold, 150);
      expect(metrics.rangeRepInvalidReason, 'form joints missing');
      expect(metrics.selectedRangeRepSide, 'left');
      expect(metrics.rangeRepAutomaticSideSelectionEnabled, isTrue);
      expect(metrics.rangeRepMovementSelectedSide, 'left');
      expect(metrics.rangeRepSideHysteresisStatus, 'locked');
      expect(metrics.currentBodyLineAngle, 170);
      expect(metrics.descendingPhaseDurationMs, 420);
      expect(metrics.descendingPhaseIssues, contains('form violation'));
      expect(metrics.phaseFeedbackCandidate, 'stabilize');
      expect(metrics.hasLastRangeRepValidation, isTrue);
      expect(metrics.lastRangeRepValidationStatus, 'invalid');
      expect(metrics.lastRangeRepValidatedRepIndex, 1);
      expect(metrics.hasLastRangeRepSummary, isTrue);
      expect(metrics.lastRangeRepSummarySelectedSideLabel, 'left');
      expect(metrics.hasLastRepBreakdown, isTrue);
      expect(metrics.lastRepRomScore, 81);
      expect(metrics.calibrationThresholdOffsetApplied, isTrue);
      expect(metrics.calibrationThresholdAppliedCount, 3);
      expect(
        metrics.sessionCalibrationBaselineCandidate?.selectedSideLabel,
        'left',
      );
    },
  );

  test(
    'buildHold produces hold-only metrics without range-rep placeholders',
    () {
      final currentSignalValues = HoldSignalValues(
        values: <HoldSignal, double>{
          HoldSignal.alignment: 168,
          HoldSignal.support: 88,
          HoldSignal.extension: 170,
        },
      );
      final targetSignalValues = HoldSignalValues(
        values: <HoldSignal, double>{HoldSignal.alignment: 166},
      );
      final signalValidity = HoldSignalValidity(
        values: <HoldSignal, bool>{
          HoldSignal.alignment: true,
          HoldSignal.support: true,
          HoldSignal.extension: true,
        },
      );
      final metrics = builder.buildHold(
        currentFormMetric: 168,
        currentSignalValues: currentSignalValues,
        targetSignalValues: targetSignalValues,
        signalValidity: signalValidity,
      );

      expect(metrics.analysisKind.name, 'hold');
      expect(metrics.hold, isNotNull);
      expect(metrics.rangeRep, isNull);
      expect(metrics.currentBackAngle, 168);
      expect(metrics.formThreshold, 166);
      expect(metrics.currentBodyLineAngle, 168);
      expect(metrics.currentArmSupportAngle, 88);
      expect(metrics.currentLegExtensionAngle, 170);
      expect(
        metrics.currentHoldSignalValues.asMap(),
        currentSignalValues.asMap(),
      );
      expect(
        metrics.targetHoldSignalValues.asMap(),
        targetSignalValues.asMap(),
      );
      expect(metrics.holdSignalValidity.asMap(), signalValidity.asMap());
      expect(metrics.hasBodyLineAngle, isTrue);
      expect(metrics.hasArmSupportAngle, isTrue);
      expect(metrics.hasLegExtensionAngle, isTrue);
      expect(metrics.selectedRangeRepSide, isNull);
      expect(metrics.hasLastRangeRepValidation, isFalse);
      expect(metrics.rangeRepValidatedCount, 0);
      expect(metrics.rangeRepLowConfidenceCount, 0);
      expect(metrics.rangeRepInvalidCount, 0);
      expect(metrics.calibrationSnapshot, isNull);
      expect(metrics.calibrationThresholdDecisionCount, 0);
    },
  );
}
