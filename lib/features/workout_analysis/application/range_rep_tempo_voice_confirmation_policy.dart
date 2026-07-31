import '../domain/models/range_rep_validation_result.dart';

/// Controls spoken feedback for completed range-rep outcomes.
///
/// P0.2 keeps tempo announcements disabled by default while the timing signal
/// is quarantined. The consecutive-repetition path remains available behind an
/// explicit opt-in so Tempo Measurement V2 can reuse and revalidate it later.
/// Measurement-quality cautions stay visual-only and technique feedback remains
/// immediate.
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
  }) {
    if (reasons.any((reason) => reason.isTechniqueOutcomeReason)) {
      reset();
      return true;
    }

    if (reasons.any((reason) => reason.isMeasurementQualityReason)) {
      reset();
      return false;
    }

    final tempoReasons =
        reasons
            .where((reason) => reason.isTempoMeasurementReason)
            .map((reason) => reason.name)
            .toList(growable: false)
          ..sort();
    if (tempoReasons.isNotEmpty && !tempoAnnouncementsEnabled) {
      reset();
      return false;
    }
    if (tempoReasons.isEmpty || status == RangeRepValidationStatus.valid) {
      reset();
      return true;
    }

    final signature = tempoReasons.join('|');
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
