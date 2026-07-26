import '../../domain/models/range_rep_validation_result.dart';

enum RangeRepOutcomeTone { positive, caution, invalid }

class RangeRepOutcomeViewData {
  const RangeRepOutcomeViewData({
    required this.repIndex,
    required this.status,
    required this.title,
    required this.message,
    required this.tone,
    this.primaryReason,
  });

  final int repIndex;
  final RangeRepValidationStatus status;
  final RangeRepValidationReason? primaryReason;
  final String title;
  final String message;
  final RangeRepOutcomeTone tone;

  String get deliveryId =>
      'range-rep-outcome:${status.name}:${primaryReason?.name ?? 'none'}';
}
