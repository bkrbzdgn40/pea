import 'package:flutter/foundation.dart';

enum LiveHudMode { minimal, detailed }

@immutable
class LiveHudVisibilityPolicy {
  const LiveHudVisibilityPolicy({
    required this.mode,
    required this.isPaused,
    required this.hasCriticalWarning,
  });

  final LiveHudMode mode;
  final bool isPaused;
  final bool hasCriticalWarning;

  bool get showActiveHud => !isPaused && !hasCriticalWarning;

  bool get showDetailedContent =>
      !hasCriticalWarning && (isPaused || mode == LiveHudMode.detailed);

  bool get showSecondaryMetric => showDetailedContent;

  bool get showTechnicalMetrics => showDetailedContent;

  bool get showProgressContext => showDetailedContent;

  bool get showFinishAction => isPaused || showDetailedContent;
}
