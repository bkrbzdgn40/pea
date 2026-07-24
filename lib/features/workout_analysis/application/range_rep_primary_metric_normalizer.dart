import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Normalizes image-plane range-rep metrics against a valid neutral setup.
///
/// Joint-angle metrics are already invariant to a rigid image rotation. An
/// image-plane segment inclination is not: rotating the camera changes the
/// absolute segment angle even when the user's pose is unchanged.
///
/// For the Sit-up contract, the first accepted pose must also represent the
/// relaxed, lying setup. The rotation-invariant shoulder-hip-knee angle gates
/// baseline acquisition, so entering the camera at the top of a Sit-up cannot
/// be mistaken for neutral. A small tolerance keeps the setup practical for a
/// torso that is slightly raised from the floor.
class RangeRepPrimaryMetricNormalizer {
  RangeRepPrimaryMetricNormalizer({
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
  }) : _config = config,
       _rangeRepContract = rangeRepContract;

  static const double _setupToleranceDegrees = 10.0;
  static const double _armedNeutralMarginDegrees = 1.0;

  final ExerciseConfig _config;
  final RangeRepContract _rangeRepContract;
  final Map<RangeRepSide, _SideSetupState> _sideStates =
      <RangeRepSide, _SideSetupState>{};

  bool get _requiresNormalization =>
      _rangeRepContract.primaryMetricKind ==
          RangeRepPrimaryMetricKind.imagePlaneInclination &&
      _rangeRepContract.primaryMetricDirection ==
          RangeRepPrimaryMetricDirection.decreasingToPeak &&
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

    final shoulder =
        pose.landmarks[resolveRangeRepLandmarkForSide(
          _config.joint1,
          metrics.side,
        )];
    final hip =
        pose.landmarks[resolveRangeRepLandmarkForSide(
          _config.primaryJoint,
          metrics.side,
        )];
    final knee =
        pose.landmarks[resolveRangeRepLandmarkForSide(
          _config.joint2,
          metrics.side,
        )];
    if (shoulder == null || hip == null || knee == null) {
      return _withPrimaryMetric(metrics, _config.thresholdNeutral);
    }

    final setupAngle = _innerAngleDegrees(shoulder, hip, knee);
    if (setupAngle == null) {
      return _withPrimaryMetric(metrics, _config.thresholdNeutral);
    }

    final state = _sideStates.putIfAbsent(
      metrics.side,
      () => _SideSetupState(
        neutralThreshold: _config.thresholdNeutral,
        metricDirection: _rangeRepContract.primaryMetricDirection,
      ),
    );
    final normalizedPrimaryMetric = state.normalize(setupAngle);

    return _withPrimaryMetric(metrics, normalizedPrimaryMetric);
  }

  RangeRepSideMetrics _withPrimaryMetric(
    RangeRepSideMetrics metrics,
    double primaryMetric,
  ) {
    return RangeRepSideMetrics(
      side: metrics.side,
      primaryAngle: primaryMetric,
      formMetric: metrics.formMetric,
      hasPrimaryAngle: metrics.hasPrimaryAngle,
      hasFormMetric: metrics.hasFormMetric,
      sideConfidence: metrics.sideConfidence,
      formSignals: _replacePrimaryDerivedDepthMetric(
        metrics.formSignals,
        primaryMetric,
      ),
    );
  }

  double? _innerAngleDegrees(
    PoseLandmark first,
    PoseLandmark middle,
    PoseLandmark last,
  ) {
    final firstDx = first.x - middle.x;
    final firstDy = first.y - middle.y;
    final lastDx = last.x - middle.x;
    final lastDy = last.y - middle.y;
    if ((firstDx == 0.0 && firstDy == 0.0) ||
        (lastDx == 0.0 && lastDy == 0.0)) {
      return null;
    }

    return AngleCalculator.calculate(
      math.Point<double>(first.x, first.y),
      math.Point<double>(middle.x, middle.y),
      math.Point<double>(last.x, last.y),
    );
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

class _SideSetupState {
  _SideSetupState({
    required this.neutralThreshold,
    required this.metricDirection,
  });

  final double neutralThreshold;
  final RangeRepPrimaryMetricDirection metricDirection;

  double? _baselineSetupAngle;
  double? _baselineMetric;

  double normalize(double setupAngle) {
    final baselineSetupAngle = _baselineSetupAngle;
    if (baselineSetupAngle == null) {
      if (!_isEligibleSetup(setupAngle)) {
        return neutralThreshold;
      }
      _setBaseline(setupAngle);
      return _baselineMetric!;
    }

    _expandBaselineTowardNeutral(setupAngle);
    final currentBaselineSetupAngle = _baselineSetupAngle!;
    final currentBaselineMetric = _baselineMetric!;
    final movementProgress = switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak => math.max(
        0.0,
        currentBaselineSetupAngle - setupAngle,
      ),
      RangeRepPrimaryMetricDirection.increasingToPeak => math.max(
        0.0,
        setupAngle - currentBaselineSetupAngle,
      ),
    };

    final normalized = switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        currentBaselineMetric - movementProgress,
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        currentBaselineMetric + movementProgress,
    };
    return normalized.clamp(0.0, 180.0).toDouble();
  }

  bool _isEligibleSetup(double setupAngle) {
    return switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        setupAngle >=
            neutralThreshold -
                RangeRepPrimaryMetricNormalizer._setupToleranceDegrees,
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        setupAngle <=
            neutralThreshold +
                RangeRepPrimaryMetricNormalizer._setupToleranceDegrees,
    };
  }

  void _setBaseline(double setupAngle) {
    _baselineSetupAngle = setupAngle;
    _baselineMetric = switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        math
            .max(
              setupAngle,
              neutralThreshold +
                  RangeRepPrimaryMetricNormalizer._armedNeutralMarginDegrees,
            )
            .toDouble(),
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        math
            .min(
              setupAngle,
              neutralThreshold -
                  RangeRepPrimaryMetricNormalizer._armedNeutralMarginDegrees,
            )
            .toDouble(),
    };
  }

  void _expandBaselineTowardNeutral(double setupAngle) {
    final baselineSetupAngle = _baselineSetupAngle!;
    final isMoreNeutral = switch (metricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        setupAngle > baselineSetupAngle,
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        setupAngle < baselineSetupAngle,
    };
    if (isMoreNeutral) {
      _setBaseline(setupAngle);
    }
  }
}
