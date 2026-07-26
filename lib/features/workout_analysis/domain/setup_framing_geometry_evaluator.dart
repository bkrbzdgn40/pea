import 'models/exercise_setup_contract.dart';
import 'models/setup_framing_geometry.dart';

/// Resolves exercise-aware framing thresholds without depending on UI or ML Kit.
class SetupFramingThresholdResolver {
  const SetupFramingThresholdResolver();

  static const SetupFramingThresholds _standingFullBody =
      SetupFramingThresholds(
        minimumLandmarkLikelihood: 0.5,
        edgeMargin: 0.035,
        minimumBodyScaleRatio: 0.5,
        maximumBodyScaleRatio: 0.94,
        maximumHorizontalCenterOffset: 0.14,
      );

  static const SetupFramingThresholds _floorBody = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.025,
    minimumBodyScaleRatio: 0.55,
    maximumBodyScaleRatio: 0.96,
    maximumHorizontalCenterOffset: 0.18,
  );

  static const SetupFramingThresholds _wallBody = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.03,
    minimumBodyScaleRatio: 0.5,
    maximumBodyScaleRatio: 0.94,
    maximumHorizontalCenterOffset: 0.16,
  );

  static const SetupFramingThresholds _raisedSurfaceBody =
      SetupFramingThresholds(
        minimumLandmarkLikelihood: 0.5,
        edgeMargin: 0.03,
        minimumBodyScaleRatio: 0.48,
        maximumBodyScaleRatio: 0.94,
        maximumHorizontalCenterOffset: 0.18,
      );

  static const SetupFramingThresholds _upperBody = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.04,
    minimumBodyScaleRatio: 0.25,
    maximumBodyScaleRatio: 0.8,
    maximumHorizontalCenterOffset: 0.16,
  );

  static const SetupFramingThresholds _lowerBody = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.04,
    minimumBodyScaleRatio: 0.28,
    maximumBodyScaleRatio: 0.84,
    maximumHorizontalCenterOffset: 0.16,
  );

  static const SetupFramingThresholds _partialBody = SetupFramingThresholds(
    minimumLandmarkLikelihood: 0.5,
    edgeMargin: 0.035,
    minimumBodyScaleRatio: 0.35,
    maximumBodyScaleRatio: 0.9,
    maximumHorizontalCenterOffset: 0.15,
  );

  SetupFramingThresholds resolve(ExerciseSetupContract contract) {
    switch (contract.supportSurface) {
      case SetupSupportSurface.floor:
        return _floorBody;
      case SetupSupportSurface.wall:
        return _wallBody;
      case SetupSupportSurface.raisedSurface:
        return _raisedSurfaceBody;
      case SetupSupportSurface.none:
        break;
    }

    final requiredRegions = contract.bodyCoverage.requiredRegions;
    final requiresHead = requiredRegions.contains(SetupBodyRegion.head);
    final requiresFeet = requiredRegions.contains(SetupBodyRegion.feet);
    if (requiresHead && requiresFeet) {
      return _standingFullBody;
    }

    final isUpperBodyOnly = requiredRegions.every(
      <SetupBodyRegion>{
        SetupBodyRegion.head,
        SetupBodyRegion.shoulders,
        SetupBodyRegion.elbows,
        SetupBodyRegion.wrists,
        SetupBodyRegion.hips,
      }.contains,
    );
    if (isUpperBodyOnly) {
      return _upperBody;
    }

    final isLowerBodyOnly = requiredRegions.every(
      <SetupBodyRegion>{
        SetupBodyRegion.hips,
        SetupBodyRegion.knees,
        SetupBodyRegion.ankles,
        SetupBodyRegion.feet,
      }.contains,
    );
    if (isLowerBodyOnly) {
      return _lowerBody;
    }

    return _partialBody;
  }
}

/// Evaluates whether an exercise-specific body region set fits the image frame.
///
/// The evaluator intentionally does not infer real-world distance. Near/far
/// outcomes are based only on normalized landmark span inside the camera image.
class SetupFramingGeometryEvaluator {
  const SetupFramingGeometryEvaluator({
    SetupFramingThresholdResolver thresholdResolver =
        const SetupFramingThresholdResolver(),
  }) : _thresholdResolver = thresholdResolver;

  final SetupFramingThresholdResolver _thresholdResolver;

  SetupFramingAssessment evaluate({
    required ExerciseSetupContract setupContract,
    required SetupFramingPose pose,
    SetupFramingThresholds? thresholds,
  }) {
    final resolvedThresholds =
        thresholds ?? _thresholdResolver.resolve(setupContract);
    final requiredRegions = setupContract.bodyCoverage.requiredRegions;
    final visibleRegions = <SetupBodyRegion>{};
    final missingRegions = <SetupBodyRegion>{};
    final confidentRequiredPoints = <NormalizedSetupLandmark>[];
    var confidenceTotal = 0.0;

    for (final region in requiredRegions) {
      final confident = pose
          .landmarksFor(region)
          .where(
            (landmark) => landmark.isConfident(
              resolvedThresholds.minimumLandmarkLikelihood,
            ),
          )
          .toList(growable: false);
      confidentRequiredPoints.addAll(confident);

      final visible = confident
          .where((landmark) => landmark.isInsideFrame)
          .toList(growable: false);
      if (visible.isEmpty) {
        missingRegions.add(region);
        continue;
      }

      visibleRegions.add(region);
      confidenceTotal += visible
          .map((landmark) => landmark.likelihood)
          .reduce(
            (current, candidate) => candidate > current ? candidate : current,
          )
          .clamp(0.0, 1.0)
          .toDouble();
    }

    final personDetected = pose.allLandmarks.any(
      (landmark) =>
          landmark.isConfident(resolvedThresholds.minimumLandmarkLikelihood),
    );
    final requiredLandmarksVisible = missingRegions.isEmpty;
    final confidence = requiredRegions.isEmpty
        ? 0.0
        : (confidenceTotal / requiredRegions.length).clamp(0.0, 1.0).toDouble();
    final bounds = confidentRequiredPoints.isEmpty
        ? null
        : NormalizedBodyBounds.fromPoints(confidentRequiredPoints);
    final clippedEdges = _resolveClippedEdges(
      confidentRequiredPoints,
      resolvedThresholds.edgeMargin,
    );
    final horizontalCenterOffset = bounds == null ? null : bounds.centerX - 0.5;
    final bodyScaleRatio = bounds?.dominantScale;

    final status = _resolveStatus(
      personDetected: personDetected,
      requiredLandmarksVisible: requiredLandmarksVisible,
      clippedEdges: clippedEdges,
      horizontalCenterOffset: horizontalCenterOffset,
      bodyScaleRatio: bodyScaleRatio,
      thresholds: resolvedThresholds,
    );

    return SetupFramingAssessment(
      status: status,
      personDetected: personDetected,
      requiredLandmarksVisible: requiredLandmarksVisible,
      visibleRequiredRegions: visibleRegions,
      missingRequiredRegions: missingRegions,
      bodyBounds: bounds,
      horizontalCenterOffset: horizontalCenterOffset,
      topMargin: bounds?.top,
      bottomMargin: bounds == null ? null : 1 - bounds.bottom,
      bodyScaleRatio: bodyScaleRatio,
      clippedEdges: clippedEdges,
      confidence: confidence,
    );
  }

  Set<SetupFrameEdge> _resolveClippedEdges(
    Iterable<NormalizedSetupLandmark> points,
    double edgeMargin,
  ) {
    final edges = <SetupFrameEdge>{};
    for (final point in points) {
      if (point.x <= edgeMargin) {
        edges.add(SetupFrameEdge.left);
      }
      if (point.x >= 1 - edgeMargin) {
        edges.add(SetupFrameEdge.right);
      }
      if (point.y <= edgeMargin) {
        edges.add(SetupFrameEdge.top);
      }
      if (point.y >= 1 - edgeMargin) {
        edges.add(SetupFrameEdge.bottom);
      }
    }
    return edges;
  }

  SetupFramingStatus _resolveStatus({
    required bool personDetected,
    required bool requiredLandmarksVisible,
    required Set<SetupFrameEdge> clippedEdges,
    required double? horizontalCenterOffset,
    required double? bodyScaleRatio,
    required SetupFramingThresholds thresholds,
  }) {
    if (!personDetected) {
      return SetupFramingStatus.noPerson;
    }
    if (!requiredLandmarksVisible) {
      return SetupFramingStatus.incompleteCoverage;
    }
    if (clippedEdges.isNotEmpty) {
      return SetupFramingStatus.clipped;
    }
    if (bodyScaleRatio != null &&
        bodyScaleRatio > thresholds.maximumBodyScaleRatio) {
      return SetupFramingStatus.tooNear;
    }
    if (bodyScaleRatio != null &&
        bodyScaleRatio < thresholds.minimumBodyScaleRatio) {
      return SetupFramingStatus.tooFar;
    }
    if (horizontalCenterOffset != null &&
        horizontalCenterOffset.abs() >
            thresholds.maximumHorizontalCenterOffset) {
      return SetupFramingStatus.offCenter;
    }
    return SetupFramingStatus.ready;
  }
}
