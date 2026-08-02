import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_scoring_service.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_scorer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_tempo_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';

void main() {
  const service = RangeRepRepScoringService();

  test('quarantined tempo remains diagnostic and scores ROM only', () {
    final result = service.score(
      _request(
        config: _config(
          scoreWeights: const RangeRepScoreWeightsConfig(
            depthWeight: 1,
            descentControlWeight: 2,
            ascentControlWeight: 3,
          ),
        ),
      ),
    );

    expect(result.finalScore, 80.0);
    expect(result.breakdown.romScore, 80.0);
    expect(result.breakdown.descentScore, 90.0);
    expect(result.breakdown.ascentScore, 100.0);
    expect(result.breakdown.weightedBaseScore, 80.0);
    expect(result.breakdown.tempoIncludedInFinalScore, isFalse);
    expect(result.breakdown.phaseQualityPenalty, isNull);
    expect(result.breakdown.penaltyTraces.map((trace) => trace.code), <String>[
      'rom_target_shortfall',
    ]);
  });

  test(
    'eligible tempo and phase quality contribute with traceable penalties',
    () {
      final result = service.score(
        _request(
          tempoAssessment: _eligibleTempoAssessment(),
          diagnostics: const RangeRepDiagnosticsSnapshot(
            descendingPhaseAssessment: RangeRepPhaseQualityAssessment(
              status: RangeRepPhaseQualityStatus.flagged,
              issues: <RangeRepPhaseQualityIssue>[
                RangeRepPhaseQualityIssue.durationTooShort,
              ],
            ),
            ascendingPhaseAssessment: RangeRepPhaseQualityAssessment(
              status: RangeRepPhaseQualityStatus.flagged,
              issues: <RangeRepPhaseQualityIssue>[
                RangeRepPhaseQualityIssue.durationTooShort,
              ],
            ),
          ),
          measurementConfidenceCombined: 0.83,
        ),
      );

      expect(result.breakdown.runtimeBaseScore, 87.5);
      expect(result.breakdown.phaseQualityPenalty, 10.0);
      expect(result.finalScore, 77.5);
      expect(result.breakdown.tempoIncludedInFinalScore, isTrue);
      expect(result.breakdown.scoreComponents?.confidence, 83.0);
      expect(
        result.breakdown.penaltyTraces.map((trace) => trace.code),
        <String>[
          'rom_target_shortfall',
          'descent_tempo_deviation',
          'descending_phase_quality_penalty',
          'ascending_phase_quality_penalty',
        ],
      );
    },
  );

  test('measurement-quality warnings keep eligible tempo out of the score', () {
    final result = service.score(
      _request(
        tempoAssessment: _eligibleTempoAssessment(),
        validationResult: RangeRepValidationResult.lowConfidence(
          const <RangeRepValidationReason>[
            RangeRepValidationReason.coverageLoss,
          ],
        ),
        diagnostics: const RangeRepDiagnosticsSnapshot(
          descendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.flagged,
            issues: <RangeRepPhaseQualityIssue>[
              RangeRepPhaseQualityIssue.durationTooShort,
            ],
          ),
        ),
      ),
    );

    expect(result.finalScore, 80.0);
    expect(result.breakdown.tempoIncludedInFinalScore, isFalse);
    expect(result.breakdown.phaseQualityPenalty, isNull);
    expect(result.breakdown.scoreComponents?.tempo, 95.0);
    expect(result.breakdown.penaltyTraces.map((trace) => trace.code), <String>[
      'rom_target_shortfall',
    ]);
  });

  test('form and non-duration phase penalties preserve legacy semantics', () {
    final result = service.score(
      _request(
        completedRepCoreData: _completedRep(
          minAngle: 70,
          primaryRom: 100,
          descentDuration: const Duration(seconds: 2),
          hadFormViolation: true,
          worstFormMetric: 52,
        ),
        diagnostics: const RangeRepDiagnosticsSnapshot(
          descendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.flagged,
            issues: <RangeRepPhaseQualityIssue>[
              RangeRepPhaseQualityIssue.formViolation,
            ],
          ),
          ascendingPhaseAssessment: RangeRepPhaseQualityAssessment(
            status: RangeRepPhaseQualityStatus.observed,
          ),
        ),
      ),
    );

    expect(result.breakdown.romScore, 100.0);
    expect(result.breakdown.runtimeBaseScore, 50.0);
    expect(result.breakdown.phaseQualityPenalty, 5.0);
    expect(result.finalScore, 45.0);
    expect(result.breakdown.scoreComponents?.technique, 50.0);
    expect(result.breakdown.scoreComponents?.consistency, 95.0);
    expect(result.breakdown.scoreComponents?.confidence, isNull);
    expect(result.breakdown.penaltyTraces.map((trace) => trace.code), <String>[
      'legacy_form_penalty',
      'descending_phase_quality_penalty',
    ]);
  });

  test('increasing-to-peak contracts score primary ROM against target max', () {
    final result = service.score(
      _request(
        config: _config(
          thresholdNeutral: 70,
          thresholdActive: 100,
          thresholdPeak: 150,
          targetMinAngle: 0,
          targetMaxAngle: 150,
        ),
        contract: RangeRepContracts.calfRaise,
        validationConfig: const RangeRepValidationConfig(
          minAcceptableRomDelta: 40,
        ),
        completedRepCoreData: _completedRep(
          minAngle: 130,
          startAngle: 70,
          primaryRom: 60,
        ),
      ),
    );

    expect(result.breakdown.romRegion, RangeRepRomRegion.acceptable);
    expect(result.breakdown.romScore, 80.0);
    expect(result.finalScore, 80.0);
    expect(result.breakdown.penaltyTraces.single.referenceValue, 80.0);
  });
}

RangeRepRepScoringRequest _request({
  ExerciseConfig? config,
  RangeRepContract? contract,
  RangeRepValidationConfig validationConfig = const RangeRepValidationConfig(),
  RangeRepCompletedRepCoreData? completedRepCoreData,
  RangeRepDiagnosticsSnapshot diagnostics = const RangeRepDiagnosticsSnapshot(),
  RangeRepValidationResult? validationResult,
  RepTempoAssessment? tempoAssessment,
  double? measurementConfidenceCombined,
}) {
  return RangeRepRepScoringRequest(
    completedRepCoreData: completedRepCoreData ?? _completedRep(),
    postUpdateDiagnostics: diagnostics,
    validationResult: validationResult ?? RangeRepValidationResult.valid(),
    tempoAssessment: tempoAssessment,
    config: config ?? _config(),
    rangeRepContract: contract ?? RangeRepContracts.squat,
    rangeRepValidationConfig: validationConfig,
    measurementConfidenceCombined: measurementConfidenceCombined,
  );
}

ExerciseConfig _config({
  double thresholdNeutral = 170,
  double thresholdActive = 140,
  double thresholdPeak = 90,
  double targetMinAngle = 70,
  double? targetMaxAngle,
  RangeRepScoreWeightsConfig? scoreWeights,
}) {
  return ExerciseConfig(
    name: 'Scoring fixture',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: thresholdNeutral,
    thresholdActive: thresholdActive,
    thresholdPeak: thresholdPeak,
    idealDescentSeconds: 2,
    idealAscentSeconds: 1,
    formThreshold: 45,
    targetMinAngle: targetMinAngle,
    targetMaxAngle: targetMaxAngle,
    tempoPenaltyPerSecond: 20,
    rangeRepScoreWeights: scoreWeights,
  );
}

RangeRepCompletedRepCoreData _completedRep({
  double minAngle = 90,
  double startAngle = 170,
  double primaryRom = 80,
  double worstFormMetric = 35,
  Duration descentDuration = const Duration(milliseconds: 1500),
  Duration ascentDuration = const Duration(seconds: 1),
  bool hadFormViolation = false,
}) {
  return RangeRepCompletedRepCoreData(
    repIndex: 1,
    minAngle: minAngle,
    startAngle: startAngle,
    primaryRom: primaryRom,
    worstFormMetric: worstFormMetric,
    descentDuration: descentDuration,
    ascentDuration: ascentDuration,
    hadFormViolation: hadFormViolation,
    completedPhaseSequence: true,
  );
}

RepTempoAssessment _eligibleTempoAssessment() {
  return RepTempoAssessment(
    quality: RepTempoQuality.target,
    severity: RepTempoSeverity.none,
    reasons: const <RepTempoReason>[],
    measurement: TempoMeasurementAssessment(
      status: TempoMeasurementStatus.eligible,
      issues: const <TempoMeasurementIssue>[],
      measuredTempo: const TempoRepResult(
        repIndex: 1,
        eccentricDuration: Duration(milliseconds: 1500),
        bottomPauseDuration: Duration.zero,
        concentricDuration: Duration(seconds: 1),
        topPauseDuration: Duration.zero,
        totalRepDuration: Duration(milliseconds: 2500),
        towardPeakDuration: Duration(milliseconds: 1500),
        returnDuration: Duration(seconds: 1),
      ),
      trace: null,
    ),
    coachingEnabled: true,
  );
}
