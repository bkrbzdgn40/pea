import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../domain/models/workout_session.dart';
import '../formatters/session_measurement_evidence_presenter.dart';

class SessionMeasurementEvidenceNotice extends StatelessWidget {
  const SessionMeasurementEvidenceNotice({super.key, required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    if (!SessionMeasurementEvidencePresenter.shouldShowWarning(session)) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    return AppFeedbackBanner(
      title: SessionMeasurementEvidencePresenter.warningTitle(
        localizations,
        session,
      ),
      message: SessionMeasurementEvidencePresenter.warningMessage(
        localizations,
        session,
      ),
      tone: SessionMeasurementEvidencePresenter.warningTone(session),
      icon: SessionMeasurementEvidencePresenter.warningIcon(session),
      liveRegion: false,
    );
  }
}
