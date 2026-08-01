import '../../domain/models/range_rep_validation_result.dart';
import '../../domain/models/rep_tempo_assessment.dart';

enum RangeRepOutcomeTone { positive, caution, invalid }

enum RangeRepTechniqueOutcome { accepted, caution, rejected }

enum RangeRepMeasurementConfidence { reliable, limited }

class RangeRepOutcomeViewData {
  const RangeRepOutcomeViewData({
    required this.repIndex,
    required this.status,
    required this.title,
    required this.message,
    required this.tone,
    this.primaryReason,
    this.techniqueOutcome = RangeRepTechniqueOutcome.accepted,
    this.measurementConfidence = RangeRepMeasurementConfidence.reliable,
    this.tempoQuality,
    this.tempoSeverity,
    this.tempoReasons = const <RepTempoReason>[],
  });

  final int repIndex;
  final RangeRepValidationStatus status;
  final RangeRepValidationReason? primaryReason;
  final String title;
  final String message;
  final RangeRepOutcomeTone tone;
  final RangeRepTechniqueOutcome techniqueOutcome;
  final RangeRepMeasurementConfidence measurementConfidence;
  final RepTempoQuality? tempoQuality;
  final RepTempoSeverity? tempoSeverity;
  final List<RepTempoReason> tempoReasons;

  bool get hasLimitedMeasurementConfidence =>
      measurementConfidence == RangeRepMeasurementConfidence.limited;

  String get deliveryId =>
      'range-rep-outcome:${status.name}:${primaryReason?.name ?? 'none'}:'
      '${tempoQuality?.name ?? 'no-tempo'}:'
      '${tempoReasons.isEmpty ? 'none' : tempoReasons.first.name}';
}
