import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/workout_rep.dart';
import '../models/range_rep_outcome_view_data.dart';

/// Single presentation policy for Measurement Confidence V2.
abstract final class MeasurementConfidencePresentationFormatter {
  static const double reliableThreshold = 0.80;

  static RangeRepMeasurementConfidence classify(double? combined) {
    if (combined == null) {
      return RangeRepMeasurementConfidence.unknown;
    }
    return combined >= reliableThreshold
        ? RangeRepMeasurementConfidence.reliable
        : RangeRepMeasurementConfidence.limited;
  }

  static String percentage(AppLocalizations localizations, double? combined) {
    if (combined == null) {
      return '--';
    }
    final value = (combined * 100).round();
    return localizations.pick(tr: '%$value', en: '$value%');
  }

  static String liveLabel(AppLocalizations localizations, double? combined) {
    final classification = classify(combined);
    final status = switch (classification) {
      RangeRepMeasurementConfidence.reliable =>
        localizations.measurementConfidenceReliable,
      RangeRepMeasurementConfidence.limited =>
        localizations.measurementConfidenceLimited,
      RangeRepMeasurementConfidence.unknown =>
        localizations.measurementConfidenceUnknown,
    };
    return localizations.measurementConfidenceValue(
      percentage(localizations, combined),
      status,
    );
  }

  static double? averageKnown(Iterable<WorkoutRep> reps) {
    var total = 0.0;
    var count = 0;
    for (final rep in reps) {
      final combined = rep.effectiveMeasurementConfidence?.combined;
      if (combined == null) {
        continue;
      }
      total += combined;
      count += 1;
    }
    return count == 0 ? null : total / count;
  }
}
