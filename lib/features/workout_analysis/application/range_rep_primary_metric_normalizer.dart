import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Normalizes image-plane range-rep metrics against the user's neutral pose.
///
/// Joint-angle metrics are already invariant to a rigid image rotation. An
/// image-plane segment inclination is not: rotating the camera changes the
/// absolute segment angle even when the user's pose is unchanged. This class
/// converts that absolute orientation into signed movement progress from the
/// first accepted neutral pose while preserving the existing engine threshold
/// scale.
class RangeRepPrimaryMetricNormalizer {
  RangeRepPrimaryMetricNormalizer({
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
  }) : _config = config,
       _rangeRepContract = rangeRepContract;

  static const double _neutralReferenceOffsetDegrees = 5.0;
  static const double _movementDirectionLockDegrees = 5.0;
  static const double _orientationDiscontinuityDegrees = 80.0;

  final ExerciseConfig _config;
  final RangeRepContract _rangeRepContract;
  final Map<RangeRepSide, _SideOrientationState> _sideStates =
      <RangeRepSide, _SideOrientationState>{};

  bool get _requiresNormalization =>
      _rangeRepContract.primaryMetricKind ==
          RangeRepPrimaryMetricKind.imagePlaneInclination &&
      _rangeRepContract.sideMode == RangeRepSideMode.selectedSide;

  ExerciseMetrics normalize({
    required Pose pose,
    required ExerciseMetrics metrics,
  }) {
    if (!_requiresNormalization || !metrics.hasPose) {
      return metrics;
    }

    final leftMetrics = _normalizeSide(
      pose: pose,
      metrics: metrics.leftRangeRepMetrics,
    );
    final rightMetrics = _normalizeSide(
      pose: pose,
      metrics: metrics.rightRangeRepMetrics,
    );

    return metrics.copyWith(
      primaryAngle: leftMetrics.primaryAngle,
      hasPrimaryAngle: leftMetrics.hasPrimaryAngle,
      leftRangeRepMetrics: leftMetrics,
      rightRangeRepMetrics: rightMetrics,
    );
  }

  void reset() {
    _sideStates.clear();
  }

  RangeRepSideMetrics _normalizeSide({
    required Pose pose,
    required RangeRepSideMetrics metrics,
  }) {
    if (!metrics.hasPrimaryAngle) {
      return metrics;
    }

    final start =
        pose.landmarks[resolveRangeRepLandmarkForSide(
          _config.joint1,
          metrics.side,
        )];
    final end =
        pose.landmarks[resolveRangeRepLandmarkForSide(
          _config.primaryJoint,
          metrics.side,
        )];
    if (start == null || end == null) {
      return metrics;
    }

    final orientation = _segmentOrientationDegrees(start, end);
    if (orientation == null) {
      return metrics;
    }

    final state = _sideStates.putIfAbsent(
      metrics.side,
      () => _SideOrientationState(
        neutralReference: _neutralReference,
        metricDirection: _rangeRepContract.primaryMetricDirection,
      ),
    );
    final normalizedPrimaryMetric = state.normalize(orientation);

    return RangeRepSideMetrics(
      side: metrics.side,
      primaryAngle: normalizedPrimaryMetric,
      formMetric: metrics.formMetric,
      hasPrimaryAngle: metrics.hasPrimaryAngle,
      hasFormMetric: metrics.hasFormMetric,
      sideConfidence: metrics.sideConfidence,
      formSignals: _replacePrimaryDerivedDepthMetric(
        metrics.formSignals,
        normalizedPrimaryMetric,
      ),
    );
  }

  double get _neutralReference {
    return switch (_rangeRepContract.primaryMetricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        (_config.thresholdNeutral + _neutralReferenceOffsetDegrees)
            .clamp(0.0, 180.0)
            .toDouble(),
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        (_config.thresholdNeutral - _neutralReferenceOffsetDegrees)
            .clamp(0.0, 180.0)
            .toDouble(),
    };
  }

  double? _segmentOrientationDegrees(PoseLandmark start, PoseLandmark end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    if (dx == 0.0 && dy == 0.0) {
      return null;
    }

    final degrees = math.atan2(dy, dx) * 180.0 / math.pi;
    return (degrees % 180.0 + 180.0) % 180.0;
  }

  RangeRepFormSignals? _replacePrimaryDerivedDepthMetric(
    RangeRepFormSignals? signals,
    double normalizedPrimaryMetric,
  ) {
    if (signals == null || signals.depthMetric == null) {
      return signals;
    }

    return RangeRepFormSignals(
      torsoAngle: signals.torsoAngle,
      depthMetric: normalizedPrimaryMetric,
      alignmentMetric: signals.alignmentMetric,
      stabilityMetric: signals.stabilityMetric,
      lockoutMetric: signals.lockoutMetric,
      bottomControlMetric: signals.bottomControlMetric,
    );
  }
}

class _SideOrientationState {
  _SideOrientationState({
    required this.neutralReference,
    required this.metricDirection,
  });

  final double neutralReference;
  final RangeRepPrimaryMetricDirection metricDirection;

  double? _baselineOrientation;
  int? _movementDirection;

  double normalize(double orientation) {
    final baselineOrientation = _baselineOrientation;
    if (baselineOrientation == null) {
      _baselineOrientation = orientation;
      return neutralReference;
    }

    final signedDelta = _signedAngularDelta(baselineOrientation, orientation);
    if (signedDelta.abs() >=
        RangeRepPrimaryMetricNormalizer._orientationDiscontinuityDegrees) {
      _baselineOrientation = orientation;
      _movementDirection = null;
      return neutralReference;
    }

    if (_movementDirection == null &&
        signedDelta.abs() >=
            RangeRepPrimaryMetricNormalizer._movementDirectionLockDegrees) {
      _movementDirection = signedDelta.isNegative ? -1 : 1;
    }

    final movementDirection = _movementDirection;
    final movementProgress = movementDirection == null
        ? 0.0
        : math.max(0.0, signedDelta * movementDirection);

    final normalized = switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        neutralReference - movementProgress,
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        neutralReference + movementProgress,
    };
    return normalized.clamp(0.0, 180.0).toDouble();
  }

  double _signedAngularDelta(double from, double to) {
    var delta = (to - from) % 180.0;
    if (delta > 90.0) {
      delta -= 180.0;
    } else if (delta < -90.0) {
      delta += 180.0;
    }
    return delta;
  }
}
