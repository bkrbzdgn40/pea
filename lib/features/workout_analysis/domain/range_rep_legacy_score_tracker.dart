import 'legacy_range_rep_scorer.dart';
import 'models/exercise_config.dart';
import 'models/range_rep_contract.dart';
import 'models/rep_score_breakdown.dart';
import 'range_rep_diagnostics.dart';

/// Owns the legacy compatibility score state without participating in the
/// range-rep lifecycle state machine.
class RangeRepLegacyScoreTracker {
  RangeRepLegacyScoreTracker({
    required this.config,
    required this.primaryMetricDirection,
    LegacyRangeRepScorer scorer = const LegacyRangeRepScorer(),
  }) : _scorer = scorer;

  final ExerciseConfig config;
  final RangeRepPrimaryMetricDirection primaryMetricDirection;
  final LegacyRangeRepScorer _scorer;

  double lastRepScore = 0.0;
  RepScoreBreakdown? lastRepScoreBreakdown;

  void calculate({
    required RangeRepCompletedRepCoreData completedRepCoreData,
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    final romScore = switch (primaryMetricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        _scorer.calculateRomScore(
          minAngle: completedRepCoreData.minAngle,
          targetMinAngle: config.targetMinAngle,
        ),
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        _scorer
            .calculateSaturatingRomScore(
              achievedRom: completedRepCoreData.primaryRom ?? 0.0,
              minimumAcceptableRom: 0.0,
              targetRom:
                  ((config.targetMaxAngle ?? config.thresholdPeak) -
                          (completedRepCoreData.startAngle ??
                              config.thresholdNeutral))
                      .clamp(0.0, 180.0)
                      .toDouble(),
            )
            .score,
    };
    final descentSeconds =
        completedRepCoreData.descentDuration.inMilliseconds / 1000.0;
    final descentScore = _scorer.calculateTempoScore(
      actualSeconds: descentSeconds,
      idealSeconds: config.idealDescentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
      toleranceRatio: config.tempoToleranceRatio,
    );
    final ascentSeconds =
        completedRepCoreData.ascentDuration.inMilliseconds / 1000.0;
    final ascentScore = _scorer.calculateTempoScore(
      actualSeconds: ascentSeconds,
      idealSeconds: config.idealAscentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
      toleranceRatio: config.tempoToleranceRatio,
    );
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
    final phaseQualityPenalty = _scorer.calculatePhaseQualityPenalty(
      descendingPhaseFlagged:
          descendingPhaseAssessment.status ==
          RangeRepPhaseQualityStatus.flagged,
      ascendingPhaseFlagged:
          ascendingPhaseAssessment.status == RangeRepPhaseQualityStatus.flagged,
    );
    final baseScore = _scorer.calculateBaseScore(
      romScore: romScore,
      tempoScore: tempoScore,
      weightedBaseScore: weightedBaseScore,
      hadFormViolation: completedRepCoreData.hadFormViolation,
    );
    final phaseAdjustedScore = _scorer.calculatePhaseAdjustedScore(
      baseScore: baseScore,
      phaseQualityPenalty: phaseQualityPenalty,
    );
    final finalScore = _scorer.calculateFinalScore(
      baseScore: baseScore,
      phaseAdjustedScore: phaseAdjustedScore,
    );

    lastRepScore = finalScore;
    lastRepScoreBreakdown = RepScoreBreakdown(
      minAngle: completedRepCoreData.minAngle,
      romScore: romScore,
      descentSeconds: descentSeconds,
      descentScore: descentScore,
      ascentSeconds: ascentSeconds,
      ascentScore: ascentScore,
      worstBackAngle: completedRepCoreData.worstFormMetric,
      hadFormViolation: completedRepCoreData.hadFormViolation,
      runtimeBaseScore: baseScore,
      finalScore: finalScore,
      depthScore: depthScore,
      descentControlScore: descentControlScore,
      ascentControlScore: ascentControlScore,
      weightedBaseScore: weightedBaseScore,
      phaseQualityPenalty: phaseQualityPenalty,
      phaseAdjustedScore: phaseAdjustedScore,
    );
  }

  void reset() {
    lastRepScore = 0.0;
    lastRepScoreBreakdown = null;
  }
}
