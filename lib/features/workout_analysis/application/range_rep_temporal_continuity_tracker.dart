import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/measurement_confidence_policy.dart';
import '../domain/models/measurement_confidence_breakdown.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';
import 'prepared_exercise_analysis_context.dart';

/// Stateful frame-to-frame continuity measurement for range-rep analysis.
///
/// Histories are isolated per side and normalized by the required-landmark
/// bounding box, so translation and image scale do not directly change the
/// result. The first usable frame stays unknown. Once two prior observations
/// exist, continuity is based on a time-scaled linear motion prediction; this
/// lets fast but consistent movement remain reliable while isolated jumps are
/// penalized.
class RangeRepTemporalContinuityTracker {
  RangeRepTemporalContinuityTracker({
    MeasurementConfidencePolicy measurementConfidencePolicy =
        const MeasurementConfidencePolicy(),
    this.maximumObservationGap = const Duration(milliseconds: 750),
  }) : assert(maximumObservationGap > Duration.zero),
       _measurementConfidencePolicy = measurementConfidencePolicy;

  static const double _minimumBodyScale = 1e-6;
  static const double _residualTolerance = 0.08;
  static const double _discontinuityThreshold = 0.50;

  final MeasurementConfidencePolicy _measurementConfidencePolicy;
  final Duration maximumObservationGap;
  final Map<RangeRepSide, _SideTemporalHistory> _histories =
      <RangeRepSide, _SideTemporalHistory>{};

  /// Adds temporal continuity to both side-specific confidence seeds.
  ///
  /// A side without a pose/signal seed remains unknown and its stale history is
  /// discarded. The tracker does not invent confidence when upstream
  /// measurement dimensions are unavailable.
  ExerciseMetrics updateMetrics({
    required Pose pose,
    required ExerciseMetrics metrics,
    required PreparedExerciseAnalysisContext preparedContext,
    required DateTime observedAt,
  }) {
    final leftMetrics = _updateSideMetrics(
      pose: pose,
      metrics: metrics.leftRangeRepMetrics,
      requirementSet: preparedContext.rangeRepPoseAcceptanceFor(
        RangeRepSide.left,
      ),
      observedAt: observedAt,
    );
    final rightMetrics = _updateSideMetrics(
      pose: pose,
      metrics: metrics.rightRangeRepMetrics,
      requirementSet: preparedContext.rangeRepPoseAcceptanceFor(
        RangeRepSide.right,
      ),
      observedAt: observedAt,
    );
    final bilateralMetrics = metrics.bilateralRangeRepMetrics;

    return metrics.copyWith(
      leftRangeRepMetrics: leftMetrics,
      rightRangeRepMetrics: rightMetrics,
      bilateralRangeRepMetrics: bilateralMetrics == null
          ? null
          : RangeRepBilateralMetrics(
              primaryAngle: bilateralMetrics.primaryAngle,
              formMetric: bilateralMetrics.formMetric,
              hasPrimaryAngle: bilateralMetrics.hasPrimaryAngle,
              hasFormMetric: bilateralMetrics.hasFormMetric,
              leftPrimaryAngle: bilateralMetrics.leftPrimaryAngle,
              rightPrimaryAngle: bilateralMetrics.rightPrimaryAngle,
              leftFormScore: bilateralMetrics.leftFormScore,
              rightFormScore: bilateralMetrics.rightFormScore,
              syncScore: bilateralMetrics.syncScore,
              measurementConfidence: _combineBilateralConfidence(
                leftMetrics.measurementConfidence,
                rightMetrics.measurementConfidence,
              ),
              formSignals: bilateralMetrics.formSignals,
            ),
    );
  }

  /// Evaluates one side and returns a full breakdown with temporal data merged
  /// into the upstream pose/signal seed.
  MeasurementConfidenceBreakdown evaluate({
    required Pose pose,
    required RangeRepSide side,
    required ExerciseLandmarkRequirementSet requirementSet,
    required MeasurementConfidenceBreakdown seed,
    required DateTime observedAt,
  }) {
    final currentSnapshot = _TemporalSnapshot.tryCreate(
      pose: pose,
      observedAt: observedAt,
      requiredLandmarks: requirementSet.requiredLandmarks,
    );
    final baseIssues = seed.issues
        .where(
          (issue) =>
              issue != MeasurementConfidenceIssue.temporalHistoryUnavailable &&
              issue != MeasurementConfidenceIssue.temporalDiscontinuity,
        )
        .toList(growable: true);

    if (currentSnapshot == null) {
      _histories.remove(side);
      baseIssues.add(MeasurementConfidenceIssue.temporalHistoryUnavailable);
      return _withTemporal(
        seed: seed,
        temporalContinuity: null,
        issues: baseIssues,
      );
    }

    final history = _histories[side];
    if (history == null) {
      _histories[side] = _SideTemporalHistory(latest: currentSnapshot);
      baseIssues.add(MeasurementConfidenceIssue.temporalHistoryUnavailable);
      return _withTemporal(
        seed: seed,
        temporalContinuity: null,
        issues: baseIssues,
      );
    }

    final elapsed = observedAt.difference(history.latest.observedAt);
    if (elapsed <= Duration.zero) {
      _histories[side] = _SideTemporalHistory(latest: currentSnapshot);
      baseIssues.add(MeasurementConfidenceIssue.temporalDiscontinuity);
      return _withTemporal(
        seed: seed,
        temporalContinuity: null,
        issues: baseIssues,
      );
    }
    if (elapsed > maximumObservationGap) {
      _histories[side] = _SideTemporalHistory(latest: currentSnapshot);
      baseIssues.add(MeasurementConfidenceIssue.temporalHistoryUnavailable);
      return _withTemporal(
        seed: seed,
        temporalContinuity: null,
        issues: baseIssues,
      );
    }

    final normalizedResidual = history.previous == null
        ? _meanDisplacement(history.latest, currentSnapshot)
        : _meanPredictionResidual(
            previous: history.previous!,
            latest: history.latest,
            current: currentSnapshot,
          );
    _histories[side] = history.advanced(currentSnapshot);

    if (normalizedResidual == null || !normalizedResidual.isFinite) {
      baseIssues.add(MeasurementConfidenceIssue.temporalHistoryUnavailable);
      return _withTemporal(
        seed: seed,
        temporalContinuity: null,
        issues: baseIssues,
      );
    }

    final temporalContinuity = _continuityForResidual(normalizedResidual);
    if (temporalContinuity < _discontinuityThreshold) {
      baseIssues.add(MeasurementConfidenceIssue.temporalDiscontinuity);
    }
    return _withTemporal(
      seed: seed,
      temporalContinuity: temporalContinuity,
      issues: baseIssues,
    );
  }

  void resetSide(RangeRepSide side) {
    _histories.remove(side);
  }

  void reset() {
    _histories.clear();
  }

  RangeRepSideMetrics _updateSideMetrics({
    required Pose pose,
    required RangeRepSideMetrics metrics,
    required ExerciseLandmarkRequirementSet requirementSet,
    required DateTime observedAt,
  }) {
    final seed = metrics.measurementConfidence;
    if (seed == null) {
      resetSide(metrics.side);
      return metrics;
    }

    return metrics.copyWith(
      measurementConfidence: evaluate(
        pose: pose,
        side: metrics.side,
        requirementSet: requirementSet,
        seed: seed,
        observedAt: observedAt,
      ),
    );
  }

  MeasurementConfidenceBreakdown? _combineBilateralConfidence(
    MeasurementConfidenceBreakdown? left,
    MeasurementConfidenceBreakdown? right,
  ) {
    if (left == null || right == null) {
      return null;
    }

    double? conservative(double? leftValue, double? rightValue) {
      if (leftValue == null || rightValue == null) {
        return null;
      }
      return math.min(leftValue, rightValue);
    }

    return _measurementConfidencePolicy.evaluate(
      landmarkLikelihood: conservative(
        left.landmarkLikelihood,
        right.landmarkLikelihood,
      ),
      signalAvailability: conservative(
        left.signalAvailability,
        right.signalAvailability,
      ),
      geometryPlausibility: conservative(
        left.geometryPlausibility,
        right.geometryPlausibility,
      ),
      temporalContinuity: conservative(
        left.temporalContinuity,
        right.temporalContinuity,
      ),
      issues: <MeasurementConfidenceIssue>{
        ...left.issues,
        ...right.issues,
      }.toList(growable: false),
    );
  }

  MeasurementConfidenceBreakdown _withTemporal({
    required MeasurementConfidenceBreakdown seed,
    required double? temporalContinuity,
    required List<MeasurementConfidenceIssue> issues,
  }) {
    return _measurementConfidencePolicy.evaluate(
      landmarkLikelihood: seed.landmarkLikelihood,
      signalAvailability: seed.signalAvailability,
      geometryPlausibility: seed.geometryPlausibility,
      temporalContinuity: temporalContinuity,
      issues: issues,
    );
  }

  double? _meanDisplacement(
    _TemporalSnapshot previous,
    _TemporalSnapshot current,
  ) {
    final sharedTypes = previous.points.keys
        .where((type) => current.points.containsKey(type))
        .toList(growable: false);
    if (sharedTypes.isEmpty) {
      return null;
    }

    var total = 0.0;
    for (final type in sharedTypes) {
      total += previous.points[type]!.distanceTo(current.points[type]!);
    }
    return total / sharedTypes.length;
  }

  double? _meanPredictionResidual({
    required _TemporalSnapshot previous,
    required _TemporalSnapshot latest,
    required _TemporalSnapshot current,
  }) {
    final previousInterval = latest.observedAt.difference(previous.observedAt);
    final currentInterval = current.observedAt.difference(latest.observedAt);
    if (previousInterval <= Duration.zero || currentInterval <= Duration.zero) {
      return null;
    }

    final sharedTypes = previous.points.keys
        .where(latest.points.containsKey)
        .where((type) => current.points.containsKey(type))
        .toList(growable: false);
    if (sharedTypes.isEmpty) {
      return null;
    }

    final timeRatio =
        currentInterval.inMicroseconds / previousInterval.inMicroseconds;
    var totalResidual = 0.0;
    for (final type in sharedTypes) {
      final previousPoint = previous.points[type]!;
      final latestPoint = latest.points[type]!;
      final predictedPoint = _NormalizedPoint(
        x: latestPoint.x + (latestPoint.x - previousPoint.x) * timeRatio,
        y: latestPoint.y + (latestPoint.y - previousPoint.y) * timeRatio,
      );
      totalResidual += predictedPoint.distanceTo(current.points[type]!);
    }
    return totalResidual / sharedTypes.length;
  }

  double _continuityForResidual(double normalizedResidual) {
    final ratio = normalizedResidual / _residualTolerance;
    return (1.0 / (1.0 + (ratio * ratio))).clamp(0.0, 1.0).toDouble();
  }
}

class _SideTemporalHistory {
  const _SideTemporalHistory({required this.latest, this.previous});

  final _TemporalSnapshot latest;
  final _TemporalSnapshot? previous;

  _SideTemporalHistory advanced(_TemporalSnapshot current) {
    return _SideTemporalHistory(previous: latest, latest: current);
  }
}

class _TemporalSnapshot {
  const _TemporalSnapshot({required this.observedAt, required this.points});

  final DateTime observedAt;
  final Map<PoseLandmarkType, _NormalizedPoint> points;

  static _TemporalSnapshot? tryCreate({
    required Pose pose,
    required DateTime observedAt,
    required Set<PoseLandmarkType> requiredLandmarks,
  }) {
    if (requiredLandmarks.length < 2) {
      return null;
    }

    final rawPoints = <PoseLandmarkType, _NormalizedPoint>{};
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final type in requiredLandmarks) {
      final landmark = pose.landmarks[type];
      if (landmark == null || !landmark.x.isFinite || !landmark.y.isFinite) {
        return null;
      }
      rawPoints[type] = _NormalizedPoint(x: landmark.x, y: landmark.y);
      minX = math.min(minX, landmark.x);
      minY = math.min(minY, landmark.y);
      maxX = math.max(maxX, landmark.x);
      maxY = math.max(maxY, landmark.y);
    }

    final width = maxX - minX;
    final height = maxY - minY;
    final diagonal = math.sqrt((width * width) + (height * height));
    if (!diagonal.isFinite ||
        diagonal <= RangeRepTemporalContinuityTracker._minimumBodyScale) {
      return null;
    }

    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;
    return _TemporalSnapshot(
      observedAt: observedAt,
      points: Map<PoseLandmarkType, _NormalizedPoint>.unmodifiable(
        rawPoints.map(
          (type, point) => MapEntry<PoseLandmarkType, _NormalizedPoint>(
            type,
            _NormalizedPoint(
              x: (point.x - centerX) / diagonal,
              y: (point.y - centerY) / diagonal,
            ),
          ),
        ),
      ),
    );
  }
}

class _NormalizedPoint {
  const _NormalizedPoint({required this.x, required this.y});

  final double x;
  final double y;

  double distanceTo(_NormalizedPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }
}
