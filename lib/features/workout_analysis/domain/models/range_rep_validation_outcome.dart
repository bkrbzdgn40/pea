import 'range_rep_rep_summary.dart';
import 'range_rep_validation_result.dart';

/// Explicit validation outcome for one completed range-rep.
class RangeRepValidationOutcome {
  const RangeRepValidationOutcome({
    required this.summary,
    required this.result,
  });

  final RangeRepRepSummary summary;
  final RangeRepValidationResult result;

  int get repIndex => summary.repIndex;
  RangeRepValidationStatus get status => result.status;
  List<RangeRepValidationReason> get reasons => result.reasons;
}
