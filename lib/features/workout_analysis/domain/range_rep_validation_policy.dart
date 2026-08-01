import 'models/range_rep_rep_summary.dart';
import 'models/range_rep_validation_result.dart';

/// Controls whether raw range-rep tempo observations may affect the user-facing
/// validation outcome.
///
/// [quarantined] is the production-safe default until Tempo Measurement V2 can
/// prove that one completed cycle has enough timing integrity for coaching.
enum RangeRepTempoMeasurementMode { quarantined, enabled }

class RangeRepValidationConfig {
  const RangeRepValidationConfig({
    this.minAcceptableRomAngle = 110.0,
    this.minDescentMillis = 250,
    this.minAscentMillis = 200,
    this.minTotalRepMillis,
    this.allowLowConfidenceOnCoverageLoss = true,
    this.invalidateOnPersistentFormBreak = false,
    this.minAcceptableRomDelta,
    this.tempoMeasurementMode = RangeRepTempoMeasurementMode.quarantined,
  });

  final double minAcceptableRomAngle;
  final int minDescentMillis;
  final int minAscentMillis;

  /// Optional floor for the complete start-to-neutral repetition duration.
  ///
  /// Small-ROM exercises can cross their active and peak thresholds within a
  /// single camera interval, making individual phase durations unsuitable for
  /// speed validation. Those exercises should set their phase minima to zero
  /// and validate the complete repetition with this value instead.
  final int? minTotalRepMillis;

  final bool allowLowConfidenceOnCoverageLoss;

  /// Promotes a completed rep with a persistent form break from cautionary to
  /// invalid. Keep this disabled unless the form metric also determines whether
  /// the primary movement metric is biomechanically trustworthy.
  final bool invalidateOnPersistentFormBreak;

  /// Optional delta-based ROM floor. When present, validation uses
  /// `startAngle - peakAngle` instead of an absolute minimum angle.
  final double? minAcceptableRomDelta;

  /// Raw tempo thresholds remain useful for diagnostics while quarantined, but
  /// they must not change rep validity, accepted counts, persistence, or UI.
  final RangeRepTempoMeasurementMode tempoMeasurementMode;
}

/// Standalone range-rep validator used by the runtime validation outcome flow.
class RangeRepValidationPolicy {
  const RangeRepValidationPolicy({required this.config});

  final RangeRepValidationConfig config;

  RangeRepValidationResult evaluate(RangeRepRepSummary summary) {
    final invalidReasons = <RangeRepValidationReason>[];
    final lowConfidenceReasons = <RangeRepValidationReason>[];
    final tempoDiagnosticReasons = <RangeRepValidationReason>[];

    if (!summary.completedPhaseSequence) {
      invalidReasons.add(RangeRepValidationReason.incompletePhase);
    }

    final minAcceptableRomDelta = config.minAcceptableRomDelta;
    if (minAcceptableRomDelta != null) {
      final primaryRom = summary.primaryRom;
      if (primaryRom == null || primaryRom < minAcceptableRomDelta) {
        invalidReasons.add(RangeRepValidationReason.insufficientRom);
      }
    } else if (summary.minAngle > config.minAcceptableRomAngle) {
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
      _recordTempoFinding(
        RangeRepValidationReason.excessiveDescentSpeed,
        lowConfidenceReasons: lowConfidenceReasons,
        tempoDiagnosticReasons: tempoDiagnosticReasons,
      );
    }

    if (summary.ascentDuration.inMilliseconds < config.minAscentMillis) {
      _recordTempoFinding(
        RangeRepValidationReason.excessiveAscentSpeed,
        lowConfidenceReasons: lowConfidenceReasons,
        tempoDiagnosticReasons: tempoDiagnosticReasons,
      );
    }

    final minTotalRepMillis = config.minTotalRepMillis;
    final totalRepDuration = summary.totalRepDuration;
    if (minTotalRepMillis != null &&
        totalRepDuration != null &&
        totalRepDuration.inMilliseconds < minTotalRepMillis) {
      _recordTempoFinding(
        RangeRepValidationReason.excessiveRepSpeed,
        lowConfidenceReasons: lowConfidenceReasons,
        tempoDiagnosticReasons: tempoDiagnosticReasons,
      );
    }

    if (summary.hadFormViolation) {
      const reason = RangeRepValidationReason.persistentFormBreak;
      if (config.invalidateOnPersistentFormBreak) {
        invalidReasons.add(reason);
      } else {
        lowConfidenceReasons.add(reason);
      }
    }

    if (invalidReasons.isNotEmpty) {
      return RangeRepValidationResult.invalid(<RangeRepValidationReason>[
        ...invalidReasons,
        ...lowConfidenceReasons,
      ], tempoDiagnosticReasons: tempoDiagnosticReasons);
    }

    if (lowConfidenceReasons.isNotEmpty) {
      return RangeRepValidationResult.lowConfidence(
        lowConfidenceReasons,
        tempoDiagnosticReasons: tempoDiagnosticReasons,
      );
    }

    return RangeRepValidationResult.valid(
      tempoDiagnosticReasons: tempoDiagnosticReasons,
    );
  }

  void _recordTempoFinding(
    RangeRepValidationReason reason, {
    required List<RangeRepValidationReason> lowConfidenceReasons,
    required List<RangeRepValidationReason> tempoDiagnosticReasons,
  }) {
    tempoDiagnosticReasons.add(reason);
    if (config.tempoMeasurementMode == RangeRepTempoMeasurementMode.enabled) {
      lowConfidenceReasons.add(reason);
    }
  }
}
