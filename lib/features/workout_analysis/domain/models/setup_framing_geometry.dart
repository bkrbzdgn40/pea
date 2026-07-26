import 'dart:math' as math;

import 'exercise_setup_contract.dart';

/// Camera-frame edges used by setup framing diagnostics.
enum SetupFrameEdge { left, top, right, bottom }

/// Highest-priority framing outcome for one preparation frame.
enum SetupFramingStatus {
  noPerson,
  incompleteCoverage,
  clipped,
  tooNear,
  tooFar,
  offCenter,
  ready,
}

/// A pose landmark expressed in normalized image coordinates.
///
/// Coordinates are intentionally not clamped to 0..1. Values outside the
/// frame remain useful for detecting clipped body regions.
class NormalizedSetupLandmark {
  NormalizedSetupLandmark({
    required this.x,
    required this.y,
    required this.likelihood,
  }) {
    if (!x.isFinite || !y.isFinite || !likelihood.isFinite) {
      throw ArgumentError('Normalized setup landmarks must be finite.');
    }
  }

  final double x;
  final double y;
  final double likelihood;

  bool isConfident(double minimumLikelihood) {
    return likelihood >= minimumLikelihood;
  }

  bool get isInsideFrame => x >= 0 && x <= 1 && y >= 0 && y <= 1;
}

/// Exercise-setup pose grouped by the semantic regions declared in R1.
class SetupFramingPose {
  SetupFramingPose({
    required Map<SetupBodyRegion, List<NormalizedSetupLandmark>>
    landmarksByRegion,
  }) : landmarksByRegion =
           Map<SetupBodyRegion, List<NormalizedSetupLandmark>>.unmodifiable(
             <SetupBodyRegion, List<NormalizedSetupLandmark>>{
               for (final entry in landmarksByRegion.entries)
                 entry.key: List<NormalizedSetupLandmark>.unmodifiable(
                   entry.value,
                 ),
             },
           );

  final Map<SetupBodyRegion, List<NormalizedSetupLandmark>> landmarksByRegion;

  List<NormalizedSetupLandmark> landmarksFor(SetupBodyRegion region) {
    return landmarksByRegion[region] ?? const <NormalizedSetupLandmark>[];
  }

  Iterable<NormalizedSetupLandmark> get allLandmarks sync* {
    for (final landmarks in landmarksByRegion.values) {
      yield* landmarks;
    }
  }
}

/// Axis-aligned bounds of the confident setup landmarks.
class NormalizedBodyBounds {
  const NormalizedBodyBounds._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory NormalizedBodyBounds.fromPoints(
    Iterable<NormalizedSetupLandmark> points,
  ) {
    final values = points.toList(growable: false);
    if (values.isEmpty) {
      throw ArgumentError.value(
        values,
        'points',
        'Body bounds require at least one landmark.',
      );
    }

    var left = values.first.x;
    var top = values.first.y;
    var right = values.first.x;
    var bottom = values.first.y;

    for (final point in values.skip(1)) {
      left = math.min(left, point.x);
      top = math.min(top, point.y);
      right = math.max(right, point.x);
      bottom = math.max(bottom, point.y);
    }

    return NormalizedBodyBounds._(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get dominantScale => math.max(width, height);
}

/// Initial, non-clinical framing heuristics for a setup family.
///
/// These values operate on normalized image geometry, not real-world metres.
class SetupFramingThresholds {
  const SetupFramingThresholds({
    required this.minimumLandmarkLikelihood,
    required this.edgeMargin,
    required this.minimumBodyScaleRatio,
    required this.maximumBodyScaleRatio,
    required this.maximumHorizontalCenterOffset,
  }) : assert(minimumLandmarkLikelihood >= 0),
       assert(minimumLandmarkLikelihood <= 1),
       assert(edgeMargin >= 0),
       assert(edgeMargin < 0.5),
       assert(minimumBodyScaleRatio > 0),
       assert(minimumBodyScaleRatio < maximumBodyScaleRatio),
       assert(maximumBodyScaleRatio <= 1),
       assert(maximumHorizontalCenterOffset >= 0),
       assert(maximumHorizontalCenterOffset < 0.5);

  final double minimumLandmarkLikelihood;
  final double edgeMargin;
  final double minimumBodyScaleRatio;
  final double maximumBodyScaleRatio;
  final double maximumHorizontalCenterOffset;
}

/// Full diagnostic result produced by the framing evaluator.
class SetupFramingAssessment {
  SetupFramingAssessment({
    required this.status,
    required this.personDetected,
    required this.requiredLandmarksVisible,
    required Set<SetupBodyRegion> visibleRequiredRegions,
    required Set<SetupBodyRegion> missingRequiredRegions,
    required this.bodyBounds,
    required this.horizontalCenterOffset,
    required this.topMargin,
    required this.bottomMargin,
    required this.bodyScaleRatio,
    required Set<SetupFrameEdge> clippedEdges,
    required this.confidence,
  }) : visibleRequiredRegions = Set<SetupBodyRegion>.unmodifiable(
         visibleRequiredRegions,
       ),
       missingRequiredRegions = Set<SetupBodyRegion>.unmodifiable(
         missingRequiredRegions,
       ),
       clippedEdges = Set<SetupFrameEdge>.unmodifiable(clippedEdges);

  final SetupFramingStatus status;
  final bool personDetected;
  final bool requiredLandmarksVisible;
  final Set<SetupBodyRegion> visibleRequiredRegions;
  final Set<SetupBodyRegion> missingRequiredRegions;
  final NormalizedBodyBounds? bodyBounds;
  final double? horizontalCenterOffset;
  final double? topMargin;
  final double? bottomMargin;
  final double? bodyScaleRatio;
  final Set<SetupFrameEdge> clippedEdges;
  final double confidence;

  bool get isReady => status == SetupFramingStatus.ready;
}
