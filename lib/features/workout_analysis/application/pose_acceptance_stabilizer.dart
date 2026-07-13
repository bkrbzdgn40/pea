class PoseAcceptanceAssessment {
  const PoseAcceptanceAssessment({
    required this.shouldAcceptForAnalysis,
    required this.isTrackingStable,
    required this.didBecomeStable,
    required this.consecutiveAcceptedFrameCount,
  });

  final bool shouldAcceptForAnalysis;
  final bool isTrackingStable;
  final bool didBecomeStable;
  final int consecutiveAcceptedFrameCount;
}

/// Prevents single-frame detector hallucinations from reaching the engines.
class PoseAcceptanceStabilizer {
  PoseAcceptanceStabilizer({this.requiredConsecutiveAcceptedFrames = 2});

  final int requiredConsecutiveAcceptedFrames;

  bool _isTrackingStable = false;
  int _consecutiveAcceptedFrameCount = 0;

  bool get isTrackingStable => _isTrackingStable;

  PoseAcceptanceAssessment recordAcceptedFrame() {
    if (_isTrackingStable) {
      return PoseAcceptanceAssessment(
        shouldAcceptForAnalysis: true,
        isTrackingStable: true,
        didBecomeStable: false,
        consecutiveAcceptedFrameCount: requiredConsecutiveAcceptedFrames,
      );
    }

    _consecutiveAcceptedFrameCount += 1;
    if (_consecutiveAcceptedFrameCount < requiredConsecutiveAcceptedFrames) {
      return PoseAcceptanceAssessment(
        shouldAcceptForAnalysis: false,
        isTrackingStable: false,
        didBecomeStable: false,
        consecutiveAcceptedFrameCount: _consecutiveAcceptedFrameCount,
      );
    }

    _isTrackingStable = true;
    return PoseAcceptanceAssessment(
      shouldAcceptForAnalysis: true,
      isTrackingStable: true,
      didBecomeStable: true,
      consecutiveAcceptedFrameCount: _consecutiveAcceptedFrameCount,
    );
  }

  PoseAcceptanceAssessment recordInvalidFrame() {
    _isTrackingStable = false;
    _consecutiveAcceptedFrameCount = 0;
    return const PoseAcceptanceAssessment(
      shouldAcceptForAnalysis: false,
      isTrackingStable: false,
      didBecomeStable: false,
      consecutiveAcceptedFrameCount: 0,
    );
  }

  void reset() {
    _isTrackingStable = false;
    _consecutiveAcceptedFrameCount = 0;
  }
}
