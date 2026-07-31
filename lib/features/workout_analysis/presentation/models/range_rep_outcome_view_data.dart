import '../../domain/models/range_rep_validation_result.dart';

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
  });

  final int repIndex;
  final RangeRepValidationStatus status;
  final RangeRepValidationReason? primaryReason;
  final String title;
  final String message;
  final RangeRepOutcomeTone tone;
  final RangeRepTechniqueOutcome techniqueOutcome;
  final RangeRepMeasurementConfidence measurementConfidence;

  bool get hasLimitedMeasurementConfidence =>
      measurementConfidence == RangeRepMeasurementConfidence.limited;

  String get deliveryId =>
      'range-rep-outcome:${status.name}:${primaryReason?.name ?? 'none'}';
}
