import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../domain/models/session_measurement_evidence.dart';
import '../../domain/models/workout_session.dart';

enum SessionMeasurementEvidenceWarning {
  none,
  limited,
  insufficient,
  preparationOverridden,
}

class SessionMeasurementEvidencePresenter {
  const SessionMeasurementEvidencePresenter._();

  static SessionMeasurementEvidenceWarning warningFor(
    WorkoutSession session,
  ) {
    if (session.preparationOutcome == PreparationOutcome.overridden) {
      return SessionMeasurementEvidenceWarning.preparationOverridden;
    }

    return switch (session.measurementQuality) {
      SessionMeasurementQuality.limited =>
        SessionMeasurementEvidenceWarning.limited,
      SessionMeasurementQuality.insufficient =>
        SessionMeasurementEvidenceWarning.insufficient,
      _ => SessionMeasurementEvidenceWarning.none,
    };
  }

  static bool shouldShowWarning(WorkoutSession session) {
    return warningFor(session) != SessionMeasurementEvidenceWarning.none;
  }

  static bool shouldMarkTrendPoint({
    required PreparationOutcome preparationOutcome,
    required SessionMeasurementQuality measurementQuality,
  }) {
    return preparationOutcome == PreparationOutcome.overridden ||
        measurementQuality == SessionMeasurementQuality.limited ||
        measurementQuality == SessionMeasurementQuality.insufficient;
  }

  static String warningTitle(
    AppLocalizations localizations,
    WorkoutSession session,
  ) {
    return switch (warningFor(session)) {
      SessionMeasurementEvidenceWarning.preparationOverridden =>
        localizations.preparationOverrideWarningTitle,
      SessionMeasurementEvidenceWarning.limited =>
        localizations.limitedMeasurementWarningTitle,
      SessionMeasurementEvidenceWarning.insufficient =>
        localizations.insufficientMeasurementWarningTitle,
      SessionMeasurementEvidenceWarning.none => '',
    };
  }

  static String warningMessage(
    AppLocalizations localizations,
    WorkoutSession session,
  ) {
    return switch (warningFor(session)) {
      SessionMeasurementEvidenceWarning.preparationOverridden =>
        localizations.preparationOverrideWarningMessage,
      SessionMeasurementEvidenceWarning.limited =>
        localizations.limitedMeasurementWarningMessage,
      SessionMeasurementEvidenceWarning.insufficient =>
        localizations.insufficientMeasurementWarningMessage,
      SessionMeasurementEvidenceWarning.none => '',
    };
  }

  static AppStatusTone warningTone(WorkoutSession session) {
    return switch (warningFor(session)) {
      SessionMeasurementEvidenceWarning.insufficient => AppStatusTone.invalid,
      SessionMeasurementEvidenceWarning.limited ||
      SessionMeasurementEvidenceWarning.preparationOverridden =>
        AppStatusTone.caution,
      SessionMeasurementEvidenceWarning.none => AppStatusTone.neutral,
    };
  }

  static IconData warningIcon(WorkoutSession session) {
    return switch (warningFor(session)) {
      SessionMeasurementEvidenceWarning.preparationOverridden =>
        Icons.skip_next_rounded,
      SessionMeasurementEvidenceWarning.limited =>
        Icons.warning_amber_rounded,
      SessionMeasurementEvidenceWarning.insufficient =>
        Icons.signal_cellular_connected_no_internet_0_bar_rounded,
      SessionMeasurementEvidenceWarning.none => Icons.info_outline_rounded,
    };
  }

  static String qualityLabel(
    AppLocalizations localizations,
    SessionMeasurementQuality quality,
  ) {
    return switch (quality) {
      SessionMeasurementQuality.high => localizations.measurementQualityHigh,
      SessionMeasurementQuality.moderate =>
        localizations.measurementQualityModerate,
      SessionMeasurementQuality.limited =>
        localizations.measurementQualityLimited,
      SessionMeasurementQuality.insufficient =>
        localizations.measurementQualityInsufficient,
      SessionMeasurementQuality.unknown =>
        localizations.measurementQualityUnavailable,
    };
  }

  static String preparationLabel(
    AppLocalizations localizations,
    PreparationOutcome outcome,
  ) {
    return switch (outcome) {
      PreparationOutcome.passed => localizations.preparationPassed,
      PreparationOutcome.overridden => localizations.preparationOverridden,
      PreparationOutcome.legacyUnknown =>
        localizations.preparationUnavailable,
    };
  }

  static String? confidenceLabel(double? confidence) {
    if (confidence == null || !confidence.isFinite) {
      return null;
    }

    final percent = (confidence.clamp(0, 1) * 100).round();
    return '%$percent';
  }
}
