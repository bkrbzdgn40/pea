import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/angle_calculator.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

/// Converts a detected pose into the measurement signals the current engine uses.
class ExerciseMetricsExtractor {
  const ExerciseMetricsExtractor();

  static final RangeRepContract _emptyRangeRepContract = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{},
    supportedSignals: const <RangeRepSignal>{},
  );
  static const ExerciseLandmarkRequirements _requirements =
      ExerciseLandmarkRequirements();

  ExerciseMetrics extract(
    Pose pose,
    ExerciseConfig config, {
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    HoldContract? holdContract,
    HoldSide? holdSide,
  }) {
    final effectiveRangeRepContract = engineKind == EngineKind.rangeRep
        ? (rangeRepContract ?? RangeRepContracts.squat)
        : _emptyRangeRepContract;
    final effectiveHoldContract = engineKind == EngineKind.hold
        ? _requireHoldContract(holdContract)
        : null;
    final effectiveHoldSide = engineKind == EngineKind.hold
        ? _requireHoldSide(holdSide)
        : null;
    final leftRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.left,
      rangeRepContract: effectiveRangeRepContract,
    );
    final rightRangeRepMetrics = _extractRangeRepSideMetrics(
      pose,
      config,
      RangeRepSide.right,
      rangeRepContract: effectiveRangeRepContract,
    );
    final bilateralRangeRepMetrics =
        effectiveRangeRepContract.sideMode == RangeRepSideMode.bilateral
        ? _extractBilateralRangeRepMetrics(
            config,
            leftMetrics: leftRangeRepMetrics,
            rightMetrics: rightRangeRepMetrics,
          )
        : null;
    final engineFacingRangeRepMetrics =
        bilateralRangeRepMetrics ?? leftRangeRepMetrics;
    final bodyLineAngle = _extractHoldSignalValue(
      pose,
      config,
      holdContract: effectiveHoldContract,
      holdSide: effectiveHoldSide,
      signal: HoldSignal.alignment,
    );
    final armSupportAngle = _extractHoldSignalValue(
      pose,
      config,
      holdContract: effectiveHoldContract,
      holdSide: effectiveHoldSide,
      signal: HoldSignal.support,
    );
    final legExtensionAngle = _extractHoldSignalValue(
      pose,
      config,
      holdContract: effectiveHoldContract,
      holdSide: effectiveHoldSide,
      signal: HoldSignal.extension,
    );

    return ExerciseMetrics(
      primaryAngle: engineFacingRangeRepMetrics.primaryAngle,
      formMetric: engineFacingRangeRepMetrics.formMetric,
      hasPrimaryAngle: engineFacingRangeRepMetrics.hasPrimaryAngle,
      hasFormMetric: engineFacingRangeRepMetrics.hasFormMetric,
      bodyLineAngle: bodyLineAngle,
      armSupportAngle: armSupportAngle,
      legExtensionAngle: legExtensionAngle,
      holdSide: effectiveHoldSide,
      hasPose: true,
      landmarks: pose.landmarks.values.toList(),
      leftRangeRepMetrics: leftRangeRepMetrics,
      rightRangeRepMetrics: rightRangeRepMetrics,
      bilateralRangeRepMetrics: bilateralRangeRepMetrics,
    );
  }

  HoldContract _requireHoldContract(HoldContract? holdContract) {
    if (holdContract == null) {
      throw StateError(
        'Hold metrics extraction requires a non-null holdContract.',
      );
    }

    return holdContract;
  }

  HoldSide _requireHoldSide(HoldSide? holdSide) {
    if (holdSide == null) {
      throw StateError('Hold metrics extraction requires a non-null holdSide.');
    }

    return holdSide;
  }

  RangeRepSideMetrics _extractRangeRepSideMetrics(
    Pose pose,
    ExerciseConfig config,
    RangeRepSide side, {
    required RangeRepContract rangeRepContract,
  }) {
    final primaryAngle = _tryCalculatePrimaryAngle(pose, config, side: side);
    final formMetric = _tryCalculateFormMetric(pose, config, side: side);
    final sideConfidence = _calculateRangeRepSideConfidence(
      pose,
      config,
      rangeRepContract: rangeRepContract,
      side: side,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
    );
    final formSignals = _extractRangeRepFormSignals(
      pose,
      config,
      rangeRepContract: rangeRepContract,
      side: side,
      primaryAngle: primaryAngle,
      formMetric: formMetric,
    );

    return RangeRepSideMetrics(
      side: side,
      primaryAngle: primaryAngle ?? 180.0,
      formMetric: formMetric ?? 90.0,
      hasPrimaryAngle: primaryAngle != null,
      hasFormMetric: formMetric != null,
      sideConfidence: sideConfidence,
      formSignals: formSignals,
    );
  }

  RangeRepBilateralMetrics _extractBilateralRangeRepMetrics(
    ExerciseConfig config, {
    required RangeRepSideMetrics leftMetrics,
    required RangeRepSideMetrics rightMetrics,
  }) {
    final leftPrimaryAngle = leftMetrics.hasPrimaryAngle
        ? leftMetrics.primaryAngle
        : null;
    final rightPrimaryAngle = rightMetrics.hasPrimaryAngle
        ? rightMetrics.primaryAngle
        : null;
    final bilateralPrimaryAngle = _resolveBilateralPrimaryAngle(
      config,
      leftPrimaryAngle: leftPrimaryAngle,
      rightPrimaryAngle: rightPrimaryAngle,
    );
    final leftFormScore = leftMetrics.hasFormMetric
        ? leftMetrics.formMetric
        : null;
    final rightFormScore = rightMetrics.hasFormMetric
        ? rightMetrics.formMetric
        : null;
    final syncScore = leftPrimaryAngle != null && rightPrimaryAngle != null
        ? _clampAngleScore(180.0 - (leftPrimaryAngle - rightPrimaryAngle).abs())
        : null;
    final bilateralFormMetric =
        leftFormScore != null && rightFormScore != null && syncScore != null
        ? math.min(leftFormScore, math.min(rightFormScore, syncScore))
        : null;

    return RangeRepBilateralMetrics(
      primaryAngle: bilateralPrimaryAngle ?? 180.0,
      formMetric: bilateralFormMetric ?? 90.0,
      hasPrimaryAngle: bilateralPrimaryAngle != null,
      hasFormMetric: bilateralFormMetric != null,
      leftPrimaryAngle: leftPrimaryAngle,
      rightPrimaryAngle: rightPrimaryAngle,
      leftFormScore: leftFormScore,
      rightFormScore: rightFormScore,
      syncScore: syncScore,
      formSignals: bilateralPrimaryAngle != null || bilateralFormMetric != null
          ? RangeRepFormSignals(
              torsoAngle: bilateralFormMetric,
              depthMetric: bilateralPrimaryAngle,
            )
          : null,
    );
  }

  double _calculateRangeRepSideConfidence(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepContract rangeRepContract,
    required RangeRepSide side,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
  }) {
    final requiresPrimaryMetric = rangeRepContract.supportsSignal(
      RangeRepSignal.primaryMetric,
    );
    final requiresFormMetric = rangeRepContract.supportsSignal(
      RangeRepSignal.formMetric,
    );
    final requirementSet = _requirements.resolve(
      config: config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: rangeRepContract,
      side: side,
    );
    final requiredLandmarks = requirementSet.requiredLandmarks;
    final observedLandmarks = requiredLandmarks
        .where((landmarkType) => pose.landmarks[landmarkType] != null)
        .length;
    final landmarkCompleteness = requiredLandmarks.isEmpty
        ? 0.0
        : observedLandmarks / requiredLandmarks.length;
    final requiredSignalCount =
        (requiresPrimaryMetric ? 1 : 0) + (requiresFormMetric ? 1 : 0);
    final availableSignalCount =
        ((requiresPrimaryMetric && hasPrimaryAngle) ? 1 : 0) +
        ((requiresFormMetric && hasFormMetric) ? 1 : 0);
    final signalAvailability = requiredSignalCount == 0
        ? 0.0
        : availableSignalCount / requiredSignalCount;

    return ((landmarkCompleteness + signalAvailability) / 2.0)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  RangeRepFormSignals? _extractRangeRepFormSignals(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepContract rangeRepContract,
    required RangeRepSide side,
    required double? primaryAngle,
    required double? formMetric,
  }) {
    final signals = RangeRepFormSignals(
      torsoAngle: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.postureAngle,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      depthMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.depthMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      alignmentMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.alignmentMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      stabilityMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.stabilityMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      lockoutMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.endRangeMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
      bottomControlMetric: _extractConfiguredRangeRepSignalValue(
        pose,
        config,
        rangeRepContract,
        RangeRepSignal.bottomControlMetric,
        side: side,
        primaryAngle: primaryAngle,
        formMetric: formMetric,
      ),
    );

    return signals.hasAnyValue ? signals : null;
  }

  double? _tryCalculatePrimaryAngle(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
  }) {
    final p1 = pose.landmarks[_landmarkTypeForSide(config.joint1, side)];
    final mid = pose.landmarks[_landmarkTypeForSide(config.primaryJoint, side)];
    final p2 = pose.landmarks[_landmarkTypeForSide(config.joint2, side)];

    if (p1 != null && mid != null && p2 != null) {
      return AngleCalculator.calculate(
        math.Point(p1.x, p1.y),
        math.Point(mid.x, mid.y),
        math.Point(p2.x, p2.y),
      );
    }

    return null;
  }

  double? _tryCalculateFormMetric(
    Pose pose,
    ExerciseConfig config, {
    required RangeRepSide side,
  }) {
    return _tryCalculateSignalDefinition(
      pose,
      definition: _formMetricDefinition(config),
      side: side,
      primaryAngle: _tryCalculatePrimaryAngle(pose, config, side: side),
    );
  }

  double? _tryCalculateSideAngle(
    Pose pose, {
    required RangeRepSide side,
    required PoseLandmarkType first,
    required PoseLandmarkType middle,
    required PoseLandmarkType last,
  }) {
    return _tryCalculateAngle(
      pose,
      _landmarkTypeForSide(first, side),
      _landmarkTypeForSide(middle, side),
      _landmarkTypeForSide(last, side),
    );
  }

  double? _extractHoldSignalValue(
    Pose pose,
    ExerciseConfig config, {
    required HoldContract? holdContract,
    required HoldSide? holdSide,
    required HoldSignal signal,
  }) {
    if (holdContract == null) {
      return null;
    }

    if (!holdContract.supportsSignal(signal)) {
      return null;
    }

    final holdSignals = config.holdSignals;
    if (holdSignals == null) {
      throw StateError('Hold metrics extraction requires holdSignals config.');
    }

    final definition = holdSignals.definitionFor(signal);
    if (definition == null) {
      throw StateError(
        'Hold metrics extraction missing ${signal.name} definition.',
      );
    }

    final requiredHoldSide = holdSide;
    if (requiredHoldSide == null) {
      throw StateError('Hold metrics extraction requires a non-null holdSide.');
    }

    return _tryCalculateAngle(
      pose,
      resolveHoldLandmarkForSide(
        configuredLandmark: definition.first,
        referenceSide: holdSignals.referenceSide,
        targetSide: requiredHoldSide,
      ),
      resolveHoldLandmarkForSide(
        configuredLandmark: definition.middle,
        referenceSide: holdSignals.referenceSide,
        targetSide: requiredHoldSide,
      ),
      resolveHoldLandmarkForSide(
        configuredLandmark: definition.last,
        referenceSide: holdSignals.referenceSide,
        targetSide: requiredHoldSide,
      ),
    );
  }

  double? _tryCalculateAngle(
    Pose pose,
    PoseLandmarkType first,
    PoseLandmarkType middle,
    PoseLandmarkType last,
  ) {
    final firstLandmark = pose.landmarks[first];
    final middleLandmark = pose.landmarks[middle];
    final lastLandmark = pose.landmarks[last];

    if (firstLandmark == null ||
        middleLandmark == null ||
        lastLandmark == null) {
      return null;
    }

    return AngleCalculator.calculate(
      math.Point(firstLandmark.x, firstLandmark.y),
      math.Point(middleLandmark.x, middleLandmark.y),
      math.Point(lastLandmark.x, lastLandmark.y),
    );
  }

  PoseLandmarkType _landmarkTypeForSide(
    PoseLandmarkType landmarkType,
    RangeRepSide side,
  ) {
    return resolveRangeRepLandmarkForSide(landmarkType, side);
  }

  RangeRepSignalDefinition? _configuredRangeRepSignalDefinition(
    ExerciseConfig config,
    RangeRepContract rangeRepContract,
    RangeRepSignal signal,
  ) {
    if (!rangeRepContract.supportsSignal(signal)) {
      return null;
    }

    final resolvedSignals = config.resolvedRangeRepSignals;
    if (resolvedSignals == null) {
      return null;
    }

    return resolvedSignals.definitionFor(signal);
  }

  RangeRepSignalDefinition? _formMetricDefinition(ExerciseConfig config) {
    return config.resolvedRangeRepSignals?.postureAngle;
  }

  double? _extractConfiguredRangeRepSignalValue(
    Pose pose,
    ExerciseConfig config,
    RangeRepContract rangeRepContract,
    RangeRepSignal signal, {
    required RangeRepSide side,
    required double? primaryAngle,
    required double? formMetric,
  }) {
    final definition = _configuredRangeRepSignalDefinition(
      config,
      rangeRepContract,
      signal,
    );
    if (definition == null) {
      return null;
    }

    if (signal == RangeRepSignal.postureAngle) {
      return formMetric;
    }

    return _tryCalculateSignalDefinition(
      pose,
      definition: definition,
      side: side,
      primaryAngle: primaryAngle,
      formMetric: formMetric,
    );
  }

  double? _tryCalculateSignalDefinition(
    Pose pose, {
    required RangeRepSignalDefinition? definition,
    required RangeRepSide side,
    double? primaryAngle,
    double? formMetric,
  }) {
    if (definition == null) {
      return null;
    }

    final double? resolvedValue;
    final angle = definition.angle;
    if (angle != null) {
      resolvedValue = _tryCalculateSideAngle(
        pose,
        side: side,
        first: angle.first,
        middle: angle.middle,
        last: angle.last,
      );
    } else {
      switch (definition.source) {
        case RangeRepSignalSource.primaryMetric:
          resolvedValue = primaryAngle;
        case null:
          resolvedValue = formMetric;
      }
    }

    return _applySignalTransform(resolvedValue, definition.transform);
  }

  double? _applySignalTransform(
    double? value,
    RangeRepSignalTransform transform,
  ) {
    if (value == null) {
      return null;
    }

    switch (transform) {
      case RangeRepSignalTransform.identity:
        return value;
      case RangeRepSignalTransform.complement180:
        return _clampAngleScore(180.0 - value);
    }
  }

  double? _resolveBilateralPrimaryAngle(
    ExerciseConfig config, {
    required double? leftPrimaryAngle,
    required double? rightPrimaryAngle,
  }) {
    if (leftPrimaryAngle == null || rightPrimaryAngle == null) {
      return null;
    }

    final laggingArmAngle = math.max(leftPrimaryAngle, rightPrimaryAngle);
    if (leftPrimaryAngle > config.thresholdNeutral &&
        rightPrimaryAngle > config.thresholdNeutral) {
      return laggingArmAngle;
    }

    return laggingArmAngle.clamp(0.0, config.thresholdNeutral).toDouble();
  }

  double _clampAngleScore(double value) {
    return value.clamp(0.0, 180.0).toDouble();
  }
}
