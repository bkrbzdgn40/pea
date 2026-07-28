import 'package:flutter/widgets.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/models/session_report.dart';
import 'hold_feedback_ui_mapper.dart';
import 'range_rep_feedback_ui_mapper.dart';

String localizedSessionReportSummary(
  AppLocalizations localizations,
  SessionReport report,
) {
  if (report.isHoldSession) {
    if (report.totalHoldSeconds <= 0) {
      return localizations.holdSessionNoMeaningfulDuration;
    }
    return localizations.holdSessionSummary(
      totalSeconds: report.totalHoldSeconds,
      bestSeconds: report.bestHoldSeconds,
    );
  }

  if (!report.hasRepDetails) {
    return localizations.sessionReportSummaryOnly;
  }

  if (report.totalReps <= 0) {
    return localizations.sessionReportNoCompletedReps;
  }

  final localizedIssues = localizedSessionReportIssues(localizations, report);
  return localizations.sessionReportRangeSummary(
    totalReps: report.totalReps,
    validReps: report.validReps,
    lowConfidenceReps: report.lowConfidenceReps,
    invalidReps: report.invalidReps,
    unknownReps: report.unknownReps,
    averageScore: report.averageScore,
    topIssue: localizedIssues.isEmpty ? null : localizedIssues.first,
  );
}

List<String> localizedSessionReportIssues(
  AppLocalizations localizations,
  SessionReport report,
) {
  return report.topIssues
      .map(localizations.localizeReportIssue)
      .toList(growable: false);
}

List<String> localizedSessionReportRecommendations(
  AppLocalizations localizations,
  SessionReport report,
) {
  return report.recommendations
      .map(localizations.localizeReportRecommendation)
      .toList(growable: false);
}

String localizeStoredWorkoutFeedback({
  required String feedback,
  required String exerciseId,
  required AppLocalizations localizations,
}) {
  final normalized = _normalizedCopy(feedback);
  if (normalized.isEmpty) {
    return feedback;
  }

  final exerciseType = ExerciseType.fromIdOrNull(exerciseId);
  const turkish = AppLocalizations(Locale('tr'));
  const english = AppLocalizations(Locale('en'));

  for (final code in RangeRepFeedbackCode.values) {
    final trMessage = mapRangeRepFeedbackCodeToMessage(
      code,
      localizations: turkish,
      exerciseType: exerciseType,
    );
    final enMessage = mapRangeRepFeedbackCodeToMessage(
      code,
      localizations: english,
      exerciseType: exerciseType,
    );
    if (_matchesFeedback(normalized, trMessage, enMessage)) {
      return mapRangeRepFeedbackCodeToMessage(
        code,
        localizations: localizations,
        exerciseType: exerciseType,
      );
    }
  }

  for (final code in HoldFeedbackCode.values) {
    final trMessage = mapHoldFeedbackCodeToMessage(
      code,
      localizations: turkish,
    );
    final enMessage = mapHoldFeedbackCodeToMessage(
      code,
      localizations: english,
    );
    if (_matchesFeedback(normalized, trMessage, enMessage) ||
        _matchesLegacyHoldFeedback(normalized, code)) {
      return mapHoldFeedbackCodeToMessage(code, localizations: localizations);
    }
  }

  return feedback;
}

bool _matchesFeedback(String normalized, String trMessage, String enMessage) {
  return normalized == _normalizedCopy(trMessage) ||
      normalized == _normalizedCopy(enMessage);
}

bool _matchesLegacyHoldFeedback(String normalized, HoldFeedbackCode code) {
  final legacy = switch (code) {
    HoldFeedbackCode.preparePosition => 'Pozisyonu Hazirla',
    HoldFeedbackCode.holdPosition => 'Pozisyonu Koru',
    HoldFeedbackCode.bodyNotVisible => 'Vucut net gorunmuyor.',
    HoldFeedbackCode.alignHips => 'Kalcayi Hizala',
    HoldFeedbackCode.adjustElbowSupport => 'Dirsek Destegini Duzelt',
    HoldFeedbackCode.placeSupportElbowUnderShoulder =>
      'Destek Dirsegini Omzunun Altina Yerlestir',
    HoldFeedbackCode.useForearmSupport =>
      'Destek Dirsegini Buk Ve On Kolunu Yere Koy',
    HoldFeedbackCode.extendLegs => 'Dizleri Kaldir',
    HoldFeedbackCode.increaseHollowCompression => 'Govdeyi Biraz Daha Toparla',
    HoldFeedbackCode.extendArmsOverhead => 'Kollari Bas Ustune Uzat',
    HoldFeedbackCode.straightenKnees => 'Dizleri Duzlestir',
    HoldFeedbackCode.adjustWallSitDepth => 'Duvar Oturusu Derinligini Ayarla',
    HoldFeedbackCode.alignWallSitTorso => 'Govdeyi Duvara Hizala',
    HoldFeedbackCode.correctForm => 'Formu Duzelt',
  };
  return normalized == _normalizedCopy(legacy);
}

String _normalizedCopy(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
