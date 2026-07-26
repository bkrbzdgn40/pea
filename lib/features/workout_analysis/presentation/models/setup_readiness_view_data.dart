typedef SetupReadinessRequest = ({
  double imageWidth,
  double imageHeight,
  bool mirrorHorizontally,
});

/// High-level visual state for the preparation readiness surface.
enum SetupReadinessVisualState { checking, needsAdjustment, ready }

/// The user-facing checks shown below the preparation camera.
enum SetupReadinessCheckType { person, framing, cameraView, startPose }

/// Visual state of one preparation check item.
enum SetupReadinessCheckState { pending, needsAdjustment, complete }

class SetupReadinessCheckItem {
  const SetupReadinessCheckItem({
    required this.type,
    required this.label,
    required this.state,
  });

  final SetupReadinessCheckType type;
  final String label;
  final SetupReadinessCheckState state;
}

/// Localized, presentation-ready projection of stable setup readiness.
class SetupReadinessViewData {
  SetupReadinessViewData({
    required this.statusLabel,
    required this.message,
    required this.visualState,
    required this.isReady,
    required List<SetupReadinessCheckItem> checks,
  }) : checks = List<SetupReadinessCheckItem>.unmodifiable(checks);

  final String statusLabel;
  final String message;
  final SetupReadinessVisualState visualState;
  final bool isReady;
  final List<SetupReadinessCheckItem> checks;
}
