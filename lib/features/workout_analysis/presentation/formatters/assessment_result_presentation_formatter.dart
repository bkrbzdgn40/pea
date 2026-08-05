import '../../../../app/localization/app_localizations.dart';

/// Keeps camera-derived assessment measurements honest at the UI boundary.
///
/// The assessment engines retain their raw precision. User-facing surfaces
/// round the values and explicitly present them as estimates instead of
/// implying clinical-grade accuracy.
abstract final class AssessmentResultPresentationFormatter {
  static const String unavailableValue = '—';

  static String degrees(AppLocalizations localizations, double? value) {
    if (!_isUsable(value)) {
      return unavailableValue;
    }
    return localizations.approximateDegrees(value!.round());
  }

  static String score(AppLocalizations localizations, double? value) {
    if (!_isUsable(value)) {
      return unavailableValue;
    }
    return localizations.approximateScore(value!.round());
  }

  static String duration(AppLocalizations localizations, Duration duration) {
    final seconds = duration.inMilliseconds / Duration.millisecondsPerSecond;
    if (!seconds.isFinite) {
      return unavailableValue;
    }
    return localizations.approximateSeconds(seconds.round());
  }

  static bool _isUsable(double? value) => value != null && value.isFinite;
}
