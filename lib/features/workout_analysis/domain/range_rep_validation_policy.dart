import 'models/range_rep_rep_summary.dart';
import 'models/range_rep_validation_result.dart';

class RangeRepValidationConfig {
  const RangeRepValidationConfig({
    this.minAcceptableRomAngle = 110.0,
    this.minDescentMillis = 250,
    this.minAscentMillis = 200,
    this.allowLowConfidenceOnCoverageLoss = true,
  });

  final double minAcceptableRomAngle;
  final int minDescentMillis;
  final int minAscentMillis;
  final bool allowLowConfidenceOnCoverageLoss;
}

/// Standalone range-rep validator used by the runtime validation outcome flow.
class RangeRepValidationPolicy {
  const RangeRepValidationPolicy({required this.config});

  final RangeRepValidationConfig config;

  RangeRepValidationResult evaluate(RangeRepRepSummary summary) {
    final invalidReasons = <RangeRepValidationReason>[];
    final lowConfidenceReasons = <RangeRepValidationReason>[];

    if (!summary.completedPhaseSequence) {
      invalidReasons.add(RangeRepValidationReason.incompletePhase);
    }

    if (summary.minAngle > config.minAcceptableRomAngle) {
      invalidReasons.add(RangeRepValidationReason.insufficientRom);
    }

    if (summary.hadCoverageDrop) {
      final reason = RangeRepValidationReason.coverageLoss;
      if (config.allowLowConfidenceOnCoverageLoss) {
        lowConfidenceReasons.add(reason);
      } else {
        invalidReasons.add(reason);
      }
    }

    if (summary.switchedSideDuringRep) {
      lowConfidenceReasons.add(RangeRepValidationReason.sideSwitchDuringRep);
    }

    if (summary.descentDuration.inMilliseconds < config.minDescentMillis) {
      lowConfidenceReasons.add(RangeRepValidationReason.excessiveDescentSpeed);
    }

    if (summary.ascentDuration.inMilliseconds < config.minAscentMillis) {
      lowConfidenceReasons.add(RangeRepValidationReason.excessiveAscentSpeed);
    }

    if (summary.hadFormViolation) {
      lowConfidenceReasons.add(RangeRepValidationReason.persistentFormBreak);
    }

    if (invalidReasons.isNotEmpty) {
      return RangeRepValidationResult.invalid(<RangeRepValidationReason>[
        ...invalidReasons,
        ...lowConfidenceReasons,
      ]);
    }

    if (lowConfidenceReasons.isNotEmpty) {
      return RangeRepValidationResult.lowConfidence(lowConfidenceReasons);
    }

    return RangeRepValidationResult.valid();
  }
}
