import '../domain/legacy_range_rep_scorer.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/rep_score_breakdown.dart';
import '../domain/models/rep_tempo_assessment.dart';
import '../domain/range_rep_diagnostics.dart';
import '../domain/range_rep_validation_policy.dart';

class RangeRepRepScoringRequest {
  const RangeRepRepScoringRequest({
    required this.completedRepCoreData,
    required this.postUpdateDiagnostics,
    required this.validationResult,
    required this.config,
    required this.rangeRepContract,
    required this.rangeRepValidationConfig,
    this.tempoAssessment,
    this.measurementConfidenceCombined,
  });

  final RangeRepCompletedRepCoreData completedRepCoreData;
  final RangeRepDiagnosticsSnapshot postUpdateDiagnostics;
  final RangeRepValidationResult validationResult;
  final RepTempoAssessment? tempoAssessment;
  final ExerciseConfig config;
  final RangeRepContract rangeRepContract;
  final RangeRepValidationConfig rangeRepValidationConfig;
  final double? measurementConfidenceCombined;
}

class RangeRepRepScoringResult {
  const RangeRepRepScoringResult({
    required this.finalScore,
    required this.breakdown,
  });

  final double finalScore;
  final RepScoreBreakdown breakdown;
}

/// Pure completed-repetition scoring boundary for range-rep exercises.
///
/// The service has no coordinator, clock, provider, persistence, feedback, or
/// engine side effects. A caller supplies one immutable scoring request and
/// receives the final numeric score together with its explainable breakdown.
class RangeRepRepScoringService {
  const RangeRepRepScoringService({
    LegacyRangeRepScorer scorer = const LegacyRangeRepScorer(),
  }) : _scorer = scorer;

  final LegacyRangeRepScorer _scorer;

  RangeRepRepScoringResult score(RangeRepRepScoringRequest request) {
    final completedRepCoreData = request.completedRepCoreData;
    final postUpdateDiagnostics = request.postUpdateDiagnostics;
    final validationResult = request.validationResult;
    final tempoAssessment = request.tempoAssessment;
    final config = request.config;
    final rangeRepContract = request.rangeRepContract;
    final rangeRepValidationConfig = request.rangeRepValidationConfig;

    final startAngle = completedRepCoreData.startAngle;
    final primaryRom = completedRepCoreData.primaryRom;
    final configuredMinimumRomDelta =
        rangeRepValidationConfig.minAcceptableRomDelta;
    final minimumAcceptableRom = startAngle == null
        ? null
        : configuredMinimumRomDelta ??
              switch (rangeRepContract.primaryMetricDirection) {
                RangeRepPrimaryMetricDirection.decreasingToPeak =>
                  (startAngle - rangeRepValidationConfig.minAcceptableRomAngle)
                      .clamp(0.0, 180.0)
                      .toDouble(),
                RangeRepPrimaryMetricDirection.increasingToPeak => null,
              };
    final targetRom = startAngle == null
        ? null
        : switch (rangeRepContract.primaryMetricDirection) {
            RangeRepPrimaryMetricDirection.decreasingToPeak =>
              (startAngle - config.targetMinAngle).clamp(0.0, 180.0).toDouble(),
            RangeRepPrimaryMetricDirection.increasingToPeak =>
              ((config.targetMaxAngle ?? config.thresholdPeak) - startAngle)
                  .clamp(0.0, 180.0)
                  .toDouble(),
          };
    final romResult =
        primaryRom == null || minimumAcceptableRom == null || targetRom == null
        ? null
        : _scorer.calculateSaturatingRomScore(
            achievedRom: primaryRom,
            minimumAcceptableRom: minimumAcceptableRom,
            targetRom: targetRom,
          );
    final romScore =
        romResult?.score ??
        switch (rangeRepContract.primaryMetricDirection) {
          RangeRepPrimaryMetricDirection.decreasingToPeak =>
            _scorer.calculateRomScore(
              minAngle: completedRepCoreData.minAngle,
              targetMinAngle: config.targetMinAngle,
            ),
          RangeRepPrimaryMetricDirection.increasingToPeak =>
            primaryRom == null || targetRom == null
                ? 0.0
                : _scorer
                      .calculateSaturatingRomScore(
                        achievedRom: primaryRom,
                        minimumAcceptableRom: 0.0,
                        targetRom: targetRom,
                      )
                      .score,
        };
    final descentSeconds =
        completedRepCoreData.descentDuration.inMilliseconds / 1000.0;
    final phaseDescentScore = _scorer.calculateTempoScore(
      actualSeconds: descentSeconds,
      idealSeconds: config.idealDescentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
      toleranceRatio: config.tempoToleranceRatio,
    );
    final ascentSeconds =
        completedRepCoreData.ascentDuration.inMilliseconds / 1000.0;
    final phaseAscentScore = _scorer.calculateTempoScore(
      actualSeconds: ascentSeconds,
      idealSeconds: config.idealAscentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
      toleranceRatio: config.tempoToleranceRatio,
    );
    final totalRepDuration = completedRepCoreData.totalRepDuration;
    final totalRepSeconds = totalRepDuration == null
        ? null
        : totalRepDuration.inMilliseconds / 1000.0;
    final minTotalRepMillis = rangeRepValidationConfig.minTotalRepMillis;
    final minTotalRepSeconds = minTotalRepMillis == null
        ? null
        : minTotalRepMillis / 1000.0;
    final totalRepTempoScore =
        totalRepSeconds == null || minTotalRepSeconds == null
        ? null
        : totalRepSeconds >= minTotalRepSeconds
        ? 100.0
        : _scorer.calculateTempoScore(
            actualSeconds: totalRepSeconds,
            idealSeconds: minTotalRepSeconds,
            tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
          );
    final useLegacyTotalRepTempoScore =
        tempoAssessment?.coachingEnabled != true;
    final descentScore = useLegacyTotalRepTempoScore
        ? totalRepTempoScore ?? phaseDescentScore
        : phaseDescentScore;
    final ascentScore = useLegacyTotalRepTempoScore
        ? totalRepTempoScore ?? phaseAscentScore
        : phaseAscentScore;
    final tempoScore = (descentScore + ascentScore) / 2;
    final depthScore = romScore;
    final descentControlScore = descentScore;
    final ascentControlScore = ascentScore;
    final scoreWeights = config.rangeRepScoreWeights;
    final weightedBaseScore = scoreWeights == null
        ? null
        : _scorer.calculateWeightedBaseScore(
            depthScore: depthScore,
            descentControlScore: descentControlScore,
            ascentControlScore: ascentControlScore,
            depthWeight: scoreWeights.depthWeight ?? 1.0,
            descentControlWeight: scoreWeights.descentControlWeight ?? 1.0,
            ascentControlWeight: scoreWeights.ascentControlWeight ?? 1.0,
          );
    final includeTempoInMainScore =
        (tempoAssessment?.shouldIncludeInScore ?? false) &&
        validationResult.allowsTempoInMainScore;
    final effectiveWeightedBaseScore = includeTempoInMainScore
        ? weightedBaseScore
        : scoreWeights == null
        ? null
        : depthScore;
    final descendingPhaseFlagged =
        postUpdateDiagnostics.descendingPhaseAssessment.status ==
            RangeRepPhaseQualityStatus.flagged &&
        (includeTempoInMainScore ||
            postUpdateDiagnostics.descendingPhaseAssessment.issues.any(
              (issue) => issue != RangeRepPhaseQualityIssue.durationTooShort,
            ));
    final ascendingPhaseFlagged =
        postUpdateDiagnostics.ascendingPhaseAssessment.status ==
            RangeRepPhaseQualityStatus.flagged &&
        (includeTempoInMainScore ||
            postUpdateDiagnostics.ascendingPhaseAssessment.issues.any(
              (issue) => issue != RangeRepPhaseQualityIssue.durationTooShort,
            ));
    final phaseQualityPenalty = _scorer.calculatePhaseQualityPenalty(
      descendingPhaseFlagged: descendingPhaseFlagged,
      ascendingPhaseFlagged: ascendingPhaseFlagged,
    );
    final baseScore = _scorer.calculateBaseScore(
      romScore: romScore,
      tempoScore: tempoScore,
      weightedBaseScore: effectiveWeightedBaseScore,
      hadFormViolation: completedRepCoreData.hadFormViolation,
      includeTempo: includeTempoInMainScore,
    );
    final phaseAdjustedScore = _scorer.calculatePhaseAdjustedScore(
      baseScore: baseScore,
      phaseQualityPenalty: phaseQualityPenalty,
    );
    final finalScore = _scorer.calculateFinalScore(
      baseScore: baseScore,
      phaseAdjustedScore: phaseAdjustedScore,
    );

    final consistencyScore = (100.0 - (phaseQualityPenalty ?? 0.0))
        .clamp(0.0, 100.0)
        .toDouble();
    final scoreComponents = RepScoreComponents(
      rom: romScore,
      tempo: tempoScore,
      technique: completedRepCoreData.hadFormViolation ? 50.0 : 100.0,
      consistency: consistencyScore,
      confidence: _scoreConfidencePercent(
        request.measurementConfidenceCombined,
      ),
    );
    final penaltyTraces = <RepScorePenaltyTrace>[];
    if (romScore < 100.0) {
      penaltyTraces.add(
        RepScorePenaltyTrace(
          component: RepScoreComponentKind.rom,
          code: 'rom_target_shortfall',
          evidenceCode: primaryRom == null
              ? 'minimum_primary_angle_observation'
              : 'primary_rom_observation',
          penaltyPoints: 100.0 - romScore,
          observedValue: primaryRom ?? completedRepCoreData.minAngle,
          referenceValue: targetRom ?? config.targetMinAngle,
          observationUnit: 'degrees',
        ),
      );
    }
    if (includeTempoInMainScore) {
      if (totalRepTempoScore != null && useLegacyTotalRepTempoScore) {
        if (totalRepTempoScore < 100.0) {
          penaltyTraces.add(
            RepScorePenaltyTrace(
              component: RepScoreComponentKind.tempo,
              code: 'total_rep_tempo_shortfall',
              evidenceCode: 'total_rep_duration_observation',
              penaltyPoints: 100.0 - totalRepTempoScore,
              observedValue: totalRepSeconds,
              referenceValue: minTotalRepSeconds,
              observationUnit: 'seconds',
            ),
          );
        }
      } else {
        if (descentScore < 100.0) {
          penaltyTraces.add(
            RepScorePenaltyTrace(
              component: RepScoreComponentKind.tempo,
              code: 'descent_tempo_deviation',
              evidenceCode: 'eccentric_duration_observation',
              penaltyPoints: 100.0 - descentScore,
              observedValue: descentSeconds,
              referenceValue: config.idealDescentSeconds,
              observationUnit: 'seconds',
            ),
          );
        }
        if (ascentScore < 100.0) {
          penaltyTraces.add(
            RepScorePenaltyTrace(
              component: RepScoreComponentKind.tempo,
              code: 'ascent_tempo_deviation',
              evidenceCode: 'concentric_duration_observation',
              penaltyPoints: 100.0 - ascentScore,
              observedValue: ascentSeconds,
              referenceValue: config.idealAscentSeconds,
              observationUnit: 'seconds',
            ),
          );
        }
      }
    }
    if (completedRepCoreData.hadFormViolation) {
      penaltyTraces.add(
        RepScorePenaltyTrace(
          component: RepScoreComponentKind.technique,
          code: 'legacy_form_penalty',
          evidenceCode: 'legacy_form_threshold_violation',
          penaltyPoints: 50.0,
          observedValue: completedRepCoreData.worstFormMetric,
          referenceValue: config.formThreshold,
          observationUnit: 'degrees',
        ),
      );
    }
    if (descendingPhaseFlagged) {
      penaltyTraces.add(
        RepScorePenaltyTrace(
          component: RepScoreComponentKind.consistency,
          code: 'descending_phase_quality_penalty',
          evidenceCode:
              postUpdateDiagnostics.descendingPhaseAssessment.issues.isEmpty
              ? 'descending_phase_quality_flagged'
              : postUpdateDiagnostics.descendingPhaseAssessment.issues
                    .map((issue) => issue.name)
                    .join(','),
          penaltyPoints: 5.0,
        ),
      );
    }
    if (ascendingPhaseFlagged) {
      penaltyTraces.add(
        RepScorePenaltyTrace(
          component: RepScoreComponentKind.consistency,
          code: 'ascending_phase_quality_penalty',
          evidenceCode:
              postUpdateDiagnostics.ascendingPhaseAssessment.issues.isEmpty
              ? 'ascending_phase_quality_flagged'
              : postUpdateDiagnostics.ascendingPhaseAssessment.issues
                    .map((issue) => issue.name)
                    .join(','),
          penaltyPoints: 5.0,
        ),
      );
    }

    final breakdown = RepScoreBreakdown(
      minAngle: completedRepCoreData.minAngle,
      primaryRom: primaryRom,
      romRegion: romResult?.region,
      romScore: romScore,
      descentSeconds: descentSeconds,
      descentScore: descentScore,
      ascentSeconds: ascentSeconds,
      ascentScore: ascentScore,
      worstBackAngle: completedRepCoreData.worstFormMetric,
      hadFormViolation: completedRepCoreData.hadFormViolation,
      runtimeBaseScore: baseScore,
      finalScore: finalScore,
      scoreComponents: scoreComponents,
      penaltyTraces: List<RepScorePenaltyTrace>.unmodifiable(penaltyTraces),
      depthScore: depthScore,
      descentControlScore: descentControlScore,
      ascentControlScore: ascentControlScore,
      consistencyScore: consistencyScore,
      weightedBaseScore: effectiveWeightedBaseScore,
      phaseQualityPenalty: phaseQualityPenalty,
      phaseAdjustedScore: phaseAdjustedScore,
      totalRepSeconds: totalRepSeconds,
      totalRepTempoScore: totalRepTempoScore,
      tempoIncludedInFinalScore: includeTempoInMainScore,
    );

    return RangeRepRepScoringResult(
      finalScore: finalScore,
      breakdown: breakdown,
    );
  }

  double? _scoreConfidencePercent(double? combined) {
    if (combined == null) {
      return null;
    }
    return (combined * 100.0).clamp(0.0, 100.0).toDouble();
  }
}
