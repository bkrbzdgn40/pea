import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/rep_tempo_assessment.dart';

/// Controls spoken feedback for completed range-rep outcomes.
///
/// Technique feedback remains immediate. Reliable fast/slow coaching requires
/// the same eligible result on consecutive repetitions. Unavailable timing is
/// visual-only and never produces a spoken tempo claim.
class RangeRepTempoVoiceConfirmationPolicy {
  RangeRepTempoVoiceConfirmationPolicy({
    this.requiredConsecutiveReps = 2,
    this.tempoAnnouncementsEnabled = false,
  }) {
    if (requiredConsecutiveReps < 1) {
      throw ArgumentError.value(
        requiredConsecutiveReps,
        'requiredConsecutiveReps',
        'must be at least one',
      );
    }
  }

  final int requiredConsecutiveReps;
  final bool tempoAnnouncementsEnabled;

  String? _pendingTempoSignature;
  int _pendingTempoCount = 0;

  bool shouldAnnounce({
    required RangeRepValidationStatus status,
    required List<RangeRepValidationReason> reasons,
    RepTempoAssessment? tempoAssessment,
  }) {
    if (reasons.any((reason) => reason.isTechniqueOutcomeReason)) {
      reset();
      return true;
    }

    if (reasons.any((reason) => reason.isMeasurementQualityReason)) {
      reset();
      return false;
    }

    final assessment = tempoAssessment;
    if (assessment == null || !assessment.coachingEnabled) {
      reset();
      return true;
    }
    if (!assessment.isAvailable) {
      reset();
      return false;
    }
    if (assessment.quality == RepTempoQuality.target) {
      reset();
      return true;
    }
    if (!tempoAnnouncementsEnabled ||
        status != RangeRepValidationStatus.valid) {
      reset();
      return false;
    }

    final reasonNames =
        assessment.reasons.map((reason) => reason.name).toList(growable: false)
          ..sort();
    final signature = '${assessment.quality.name}:${reasonNames.join('|')}';
    if (_pendingTempoSignature == signature) {
      _pendingTempoCount += 1;
    } else {
      _pendingTempoSignature = signature;
      _pendingTempoCount = 1;
    }

    if (_pendingTempoCount < requiredConsecutiveReps) {
      return false;
    }

    reset();
    return true;
  }

  void reset() {
    _pendingTempoSignature = null;
    _pendingTempoCount = 0;
  }
}
